// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedParams} from "../PriceFeedParams.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {IBalancerStablePool} from "../../interfaces/balancer/IBalancerStablePool.sol";

/// @title Balancer stable pool token price feed
/// @dev Similarly to Curve stableswap, aggregate function is minimum of underlying tokens prices
contract BPTStablePriceFeed is LPPriceFeed {
    uint256 public constant override version = 3_11;
    bytes32 public constant override contractType = "PRICE_FEED::BALANCER_STABLE";

    uint8 public immutable numAssets;

    address public immutable priceFeed0;
    uint32 public immutable stalenessPeriod0;
    bool public immutable skipCheck0;

    address public immutable priceFeed1;
    uint32 public immutable stalenessPeriod1;
    bool public immutable skipCheck1;

    address public immutable priceFeed2;
    uint32 public immutable stalenessPeriod2;
    bool public immutable skipCheck2;

    address public immutable priceFeed3;
    uint32 public immutable stalenessPeriod3;
    bool public immutable skipCheck3;

    address public immutable priceFeed4;
    uint32 public immutable stalenessPeriod4;
    bool public immutable skipCheck4;

    constructor(address _owner, uint256 _lowerBound, address _balancerPool, PriceFeedParams[5] memory priceFeeds)
        LPPriceFeed(_owner, _balancerPool, _balancerPool) // U:[BAL-S-1]
        nonZeroAddress(priceFeeds[0].priceFeed) // U:[BAL-S-2]
        nonZeroAddress(priceFeeds[1].priceFeed) // U:[BAL-S-2]
    {
        priceFeed0 = priceFeeds[0].priceFeed;
        priceFeed1 = priceFeeds[1].priceFeed;
        priceFeed2 = priceFeeds[2].priceFeed;
        priceFeed3 = priceFeeds[3].priceFeed;
        priceFeed4 = priceFeeds[4].priceFeed;

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod1 = priceFeeds[1].stalenessPeriod;
        stalenessPeriod2 = priceFeeds[2].stalenessPeriod;
        stalenessPeriod3 = priceFeeds[3].stalenessPeriod;
        stalenessPeriod4 = priceFeeds[4].stalenessPeriod;

        numAssets = priceFeed2 == address(0) ? 2 : (priceFeed3 == address(0) ? 3 : (priceFeed4 == address(0) ? 4 : 5)); // U:[BAL-S-2]

        skipCheck0 = _validatePriceFeedMetadata(priceFeed0, stalenessPeriod0);
        skipCheck1 = _validatePriceFeedMetadata(priceFeed1, stalenessPeriod1);
        skipCheck2 = numAssets > 2 ? _validatePriceFeedMetadata(priceFeed2, stalenessPeriod2) : false;
        skipCheck3 = numAssets > 3 ? _validatePriceFeedMetadata(priceFeed3, stalenessPeriod3) : false;
        skipCheck4 = numAssets > 4 ? _validatePriceFeedMetadata(priceFeed4, stalenessPeriod4) : false;

        _setLimiter(_lowerBound); // U:[BAL-S-1]
    }

    function getAggregatePriceAndTimestamp() public view override returns (int256 answer, uint256 updatedAt) {
        (answer, updatedAt) = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0); // U:[BAL-S-2]

        (int256 answerA, uint256 updatedAtA) = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);
        (answer, updatedAt) = _agg(answer, updatedAt, answerA, updatedAtA); // U:[BAL-S-2]

        if (numAssets > 2) {
            (answerA, updatedAtA) = _getValidatedPrice(priceFeed2, stalenessPeriod2, skipCheck2);
            (answer, updatedAt) = _agg(answer, updatedAt, answerA, updatedAtA); // U:[BAL-S-2]

            if (numAssets > 3) {
                (answerA, updatedAtA) = _getValidatedPrice(priceFeed3, stalenessPeriod3, skipCheck3);
                (answer, updatedAt) = _agg(answer, updatedAt, answerA, updatedAtA); // U:[BAL-S-2]

                if (numAssets > 4) {
                    (answerA, updatedAtA) = _getValidatedPrice(priceFeed4, stalenessPeriod4, skipCheck4);
                    (answer, updatedAt) = _agg(answer, updatedAt, answerA, updatedAtA); // U:[BAL-S-2]
                }
            }
        }
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IBalancerStablePool(lpToken).getRate(); // U:[BAL-S-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[BAL-S-1]
    }

    function _agg(int256 answer1, uint256 updatedAt1, int256 answer2, uint256 updatedAt2)
        internal
        view
        returns (int256 answer, uint256 updatedAt)
    {
        return (answer1 < answer2 ? answer1 : answer2, updatedAt1 < updatedAt2 ? updatedAt1 : updatedAt2);
    }
}
