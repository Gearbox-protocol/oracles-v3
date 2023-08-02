// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedParams} from "../AbstractPriceFeed.sol";

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
    PriceFeedType public constant override priceFeedType = PriceFeedType.CURVE_4LP_ORACLE;

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

    constructor(
        address addressProvider,
        address _curvePool,
        PriceFeedParams[4] memory priceFeeds,
        string memory _description
    )
        AbstractCurveLPPriceFeed(addressProvider, _curvePool, _description)
        nonZeroAddress(priceFeeds[0].priceFeed)
        nonZeroAddress(priceFeeds[1].priceFeed)
    {
        priceFeed1 = priceFeeds[0].priceFeed; // F:[OCLP-1]
        priceFeed2 = priceFeeds[1].priceFeed; // F:[OCLP-1]
        priceFeed3 = priceFeeds[2].priceFeed; // F:[OCLP-1]
        priceFeed4 = priceFeeds[3].priceFeed; // F:[OCLP-1]

        stalenessPeriod1 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod2 = priceFeeds[1].stalenessPeriod;
        stalenessPeriod3 = priceFeeds[2].stalenessPeriod;
        stalenessPeriod4 = priceFeeds[3].stalenessPeriod;
    }

    /// @dev Returns the USD price of the pool's LP token
    /// @notice Computes the LP token price as (min_t(price(coin_t)) * virtual_price())
    ///         See more at https://dev.gearbox.fi/docs/documentation/oracle/curve-pricefeed
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getMinPrice(); // F:[OCLP-2]

        // Checks that virtual_priceis in limits
        uint256 virtualPrice = _getValidatedContractValue(); // F: [OCLP-7]

        answer = (answer * int256(virtualPrice)) / decimalsDivider; // F:[OCLP-4]
    }

    function _getMinPrice() internal view returns (int256 answer, uint256 updatedAt) {
        (answer, updatedAt) = _getValidatedPrice(priceFeed1, stalenessPeriod1); // F:[OCLP-6]

        (int256 answerA, uint256 updatedAtA) = _getValidatedPrice(priceFeed2, stalenessPeriod2); // F:[OCLP-6]
        if (answerA < answer) {
            answer = answerA;
            updatedAt = updatedAtA;
        } // F:[OCLP-6]

        if (priceFeed3 != address(0)) {
            (answerA, updatedAtA) = _getValidatedPrice(priceFeed3, stalenessPeriod3); // F:[OCLP-6]
            if (answerA < answer) {
                answer = answerA;
                updatedAt = updatedAtA;
            } // F:[OCLP-6]

            if (priceFeed4 != address(0)) {
                (answerA, updatedAtA) = _getValidatedPrice(priceFeed4, stalenessPeriod4); // F:[OCLP-6]
                if (answerA < answer) {
                    answer = answerA;
                    updatedAt = updatedAtA;
                } // F:[OCLP-6]
            }
        }
    }
}
