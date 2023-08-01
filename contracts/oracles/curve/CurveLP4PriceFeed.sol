// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AbstractCurveLPPriceFeed} from "./AbstractCurveLPPriceFeed.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";

// EXCEPTIONS
import {
    ZeroAddressException,
    NotImplementedException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title CurveLP pricefeed for 4 assets
contract CurveLP4PriceFeed is AbstractCurveLPPriceFeed {
    /// @dev Price feed of coin 0 in the pool
    address public immutable priceFeed1;

    uint32 public immutable stalenessPeriod1;

    /// @dev Price feed of coin 1 in the pool
    address public immutable priceFeed2;

    uint32 public immutable stalenessPeriod2;

    /// @dev Price feed of coin 2 in the pool
    address public immutable priceFeed3;
    uint32 public immutable stalenessPeriod3;

    /// @dev Price feed of coin 3 in the pool
    address public immutable priceFeed4;

    uint32 public immutable stalenessPeriod4;

    PriceFeedType public constant override priceFeedType = PriceFeedType.CURVE_4LP_ORACLE;

    constructor(
        address addressProvider,
        address _curvePool,
        address _priceFeed1,
        address _priceFeed2,
        address _priceFeed3,
        address _priceFeed4,
        uint32 _stalenessPeriod1,
        uint32 _stalenessPeriod2,
        uint32 _stalenessPeriod3,
        uint32 _stalenessPeriod4,
        string memory _description
    ) AbstractCurveLPPriceFeed(addressProvider, _curvePool, _description) {
        if (_priceFeed1 == address(0) || _priceFeed2 == address(0)) revert ZeroAddressException();

        priceFeed1 = _priceFeed1; // F:[OCLP-1]
        priceFeed2 = _priceFeed2; // F:[OCLP-1]
        priceFeed3 = _priceFeed3; // F:[OCLP-1]
        priceFeed4 = _priceFeed4; // F:[OCLP-1]

        stalenessPeriod1 = _stalenessPeriod1;
        stalenessPeriod2 = _stalenessPeriod2;
        stalenessPeriod3 = _stalenessPeriod3;
        stalenessPeriod4 = _stalenessPeriod4;
    }

    /// @dev Returns the USD price of the pool's LP token
    /// @notice Computes the LP token price as (min_t(price(coin_t)) * virtual_price())
    ///         See more at https://dev.gearbox.fi/docs/documentation/oracle/curve-pricefeed
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = getAnswer(); // F:[OCLP-2]

        uint256 virtualPrice = curvePool.get_virtual_price();

        // Checks that virtual_priceis in limits
        virtualPrice = _checkAndUpperBoundValue(virtualPrice); // F: [OCLP-7]

        answer = (answer * int256(virtualPrice)) / decimalsDivider; // F:[OCLP-4]
    }

    function getAnswer()
        internal
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 answerA;

        uint256 updatedAtA;

        (, answer,, updatedAt,) = AggregatorV3Interface(priceFeed1).latestRoundData(); // F:[OCLP-6]

        // Sanity check for chainlink pricefeed
        _checkAnswer(answer, updatedAt, 2 hours);

        (, answerA,, updatedAtA,) = AggregatorV3Interface(priceFeed2).latestRoundData(); // F:[OCLP-6]

        // Sanity check for chainlink pricefeed
        _checkAnswer(answerA, updatedAtA, 2 hours);

        if (answerA < answer) {
            answer = answerA;
            updatedAt = updatedAtA;
        } // F:[OCLP-6]

        if (priceFeed3 == address(0)) {
            return (roundId, answer, startedAt, updatedAt, answeredInRound);
        }

        (, answerA,, updatedAtA,) = AggregatorV3Interface(priceFeed3).latestRoundData(); // F:[OCLP-6]

        // Sanity check for chainlink pricefeed
        _checkAnswer(answerA, updatedAtA, 2 hours);

        if (answerA < answer) {
            answer = answerA;
            updatedAt = updatedAtA;
        } // F:[OCLP-6]

        if (priceFeed4 == address(0)) {
            return (roundId, answer, startedAt, updatedAt, answeredInRound);
        }

        (, answerA,, updatedAtA,) = AggregatorV3Interface(priceFeed3).latestRoundData(); // F:[OCLP-6]

        // Sanity check for chainlink pricefeed
        _checkAnswer(answerA, updatedAtA, 2 hours);

        if (answerA < answer) {
            answer = answerA;
            updatedAt = updatedAtA;
        } // F:[OCLP-6]
    }
}
