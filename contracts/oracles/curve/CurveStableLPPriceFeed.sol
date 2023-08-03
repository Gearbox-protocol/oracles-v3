// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedParams} from "../AbstractPriceFeed.sol";
import {AbstractCurveLPPriceFeed} from "./AbstractCurveLPPriceFeed.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";

/// @title Curve stable LP price feed
contract CurveStableLPPriceFeed is AbstractCurveLPPriceFeed {
    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public immutable override priceFeedType;

    /// @notice Number of coins in the pool
    uint16 public immutable nCoins;

    /// @notice Coin 0 price feed
    address public immutable priceFeed0;
    uint32 public immutable stalenessPeriod0;
    bool public immutable skipCheck0;

    /// @notice Coin 1 price feed
    address public immutable priceFeed1;
    uint32 public immutable stalenessPeriod1;
    bool public immutable skipCheck1;

    /// @notice Coin 2 price feed
    address public immutable priceFeed2;
    uint32 public immutable stalenessPeriod2;
    bool public immutable skipCheck2;

    /// @notice Coin 3 price feed
    address public immutable priceFeed3;
    uint32 public immutable stalenessPeriod3;
    bool public immutable skipCheck3;

    constructor(address addressProvider, address _curvePool, PriceFeedParams[4] memory priceFeeds)
        AbstractCurveLPPriceFeed(addressProvider, _curvePool)
        nonZeroAddress(priceFeeds[0].priceFeed)
        nonZeroAddress(priceFeeds[1].priceFeed)
    {
        priceFeed0 = priceFeeds[0].priceFeed;
        priceFeed1 = priceFeeds[1].priceFeed;
        priceFeed2 = priceFeeds[2].priceFeed;
        priceFeed3 = priceFeeds[3].priceFeed;

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod1 = priceFeeds[1].stalenessPeriod;
        stalenessPeriod2 = priceFeeds[2].stalenessPeriod;
        stalenessPeriod3 = priceFeeds[3].stalenessPeriod;

        nCoins = priceFeed2 == address(0) ? 2 : (priceFeed3 == address(0) ? 3 : 4);

        skipCheck0 = _validatePriceFeed(priceFeed0, stalenessPeriod0);
        skipCheck1 = _validatePriceFeed(priceFeed1, stalenessPeriod1);
        skipCheck2 = nCoins > 2 ? _validatePriceFeed(priceFeed2, stalenessPeriod2) : false;
        skipCheck3 = nCoins > 3 ? _validatePriceFeed(priceFeed3, stalenessPeriod3) : false;

        priceFeedType = nCoins == 2
            ? PriceFeedType.CURVE_2LP_ORACLE
            : (nCoins == 3 ? PriceFeedType.CURVE_3LP_ORACLE : PriceFeedType.CURVE_4LP_ORACLE);
    }

    /// @dev For stable pools, aggregate is simply the minimum of underlying tokens prices
    function _getAggregatePrice() internal view override returns (int256 answer, uint256 updatedAt) {
        (answer, updatedAt) = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0);

        (int256 answer2,) = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);
        if (answer2 < answer) answer = answer2;

        if (nCoins > 2) {
            (answer2,) = _getValidatedPrice(priceFeed2, stalenessPeriod2, skipCheck2);
            if (answer2 < answer) answer = answer2;

            if (nCoins > 3) {
                (answer2,) = _getValidatedPrice(priceFeed3, stalenessPeriod3, skipCheck3);
                if (answer2 < answer) answer = answer2;
            }
        }
    }
}
