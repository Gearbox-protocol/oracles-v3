// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AbstractCurveLPPriceFeed} from "./AbstractCurveLPPriceFeed.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";

import {FixedPoint} from "../../libraries/FixedPoint.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant DECIMALS = 10 ** 18;
uint256 constant USD_FEED_DECIMALS = 10 ** 8;

/// @title CurveLP price feed for crypto pools
contract CurveCryptoLPPriceFeed is AbstractCurveLPPriceFeed {
    using FixedPoint for uint256;

    /// @dev Price feed of coin 0 in the pool
    address public immutable priceFeed1;

    uint32 public immutable stalenessPeriod1;

    /// @dev Price feed of coin 1 in the pool
    address public immutable priceFeed2;

    uint32 public immutable stalenessPeriod2;

    /// @dev Price feed of coin 2 in the pool
    address public immutable priceFeed3;
    uint32 public immutable stalenessPeriod3;

    /// @dev Number of coins in the pool (2 or 3)
    uint16 public immutable nCoins;

    PriceFeedType public constant override priceFeedType = PriceFeedType.CURVE_CRYPTO_ORACLE;

    constructor(
        address addressProvider,
        address _curvePool,
        address _priceFeed1,
        address _priceFeed2,
        address _priceFeed3,
        uint32 _stalenessPeriod1,
        uint32 _stalenessPeriod2,
        uint32 _stalenessPeriod3,
        string memory _description
    ) AbstractCurveLPPriceFeed(addressProvider, _curvePool, _description) {
        if (_priceFeed1 == address(0) || _priceFeed2 == address(0)) revert ZeroAddressException();

        priceFeed1 = _priceFeed1; // F:[OCLP-1]
        priceFeed2 = _priceFeed2; // F:[OCLP-1]
        priceFeed3 = _priceFeed3; // F:[OCLP-1]

        stalenessPeriod1 = _stalenessPeriod1;
        stalenessPeriod2 = _stalenessPeriod2;
        stalenessPeriod3 = _stalenessPeriod3;

        nCoins = _priceFeed3 == address(0) ? 2 : 3;
    }

    /// @dev Returns the USD price of Curve Tricrypto pool's LP token
    /// @notice Computes the LP token price as n * (prod_i(price(coin_i)))^(1/n) * virtual_price()
    function latestRoundData()
        external
        view
        virtual
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 answerCurrent;
        uint256 updatedAtCurrent;

        (, answerCurrent,, updatedAtCurrent,) = AggregatorV3Interface(priceFeed1).latestRoundData(); // F:[OCLP-6]

        // Sanity check for chainlink pricefeed
        _checkAnswer(answer, updatedAt, stalenessPeriod1);

        uint256 product = uint256(answerCurrent) * DECIMALS / USD_FEED_DECIMALS;

        (, answerCurrent,, updatedAtCurrent,) = AggregatorV3Interface(priceFeed2).latestRoundData(); // F:[OCLP-6]

        // Sanity check for chainlink pricefeed
        _checkAnswer(answer, updatedAt, stalenessPeriod2);

        product = product.mulDown(uint256(answerCurrent) * DECIMALS / USD_FEED_DECIMALS);

        if (nCoins == 3) {
            (, answerCurrent,, updatedAtCurrent,) = AggregatorV3Interface(priceFeed2).latestRoundData(); // F:[OCLP-6]

            // Sanity check for chainlink pricefeed
            _checkAnswer(answer, updatedAt, stalenessPeriod3);

            product = product.mulDown(uint256(answerCurrent) * DECIMALS / USD_FEED_DECIMALS);
        }

        uint256 virtualPrice = curvePool.virtual_price();

        // Checks that virtual_price is within bounds
        virtualPrice = _checkAndUpperBoundValue(virtualPrice);

        answer = int256(product.powDown(DECIMALS / nCoins).mulDown(nCoins * virtualPrice));

        answer = answer * int256(USD_FEED_DECIMALS) / int256(DECIMALS);
    }

    function getAnswer()
        internal
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 answerA;

        uint256 updatedAtA;

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
    }
}
