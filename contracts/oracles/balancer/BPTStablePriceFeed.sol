// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedParams} from "../PriceFeedParams.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {IBalancerStablePool} from "../../interfaces/balancer/IBalancerStablePool.sol";

/// @title Balancer stable pool token price feed
/// @dev Similarly to Curve stableswap, aggregate function is minimum of underlying tokens prices
contract BPTStablePriceFeed is LPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.BALANCER_STABLE_LP_ORACLE;

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

    constructor(address addressProvider, address _balancerPool, PriceFeedParams[5] memory priceFeeds)
        LPPriceFeed(addressProvider, _balancerPool, _balancerPool) // U:[BAL-S-1]
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

        skipCheck0 = _validatePriceFeed(priceFeed0, stalenessPeriod0);
        skipCheck1 = _validatePriceFeed(priceFeed1, stalenessPeriod1);
        skipCheck2 = numAssets > 2 ? _validatePriceFeed(priceFeed2, stalenessPeriod2) : false;
        skipCheck3 = numAssets > 3 ? _validatePriceFeed(priceFeed3, stalenessPeriod3) : false;
        skipCheck4 = numAssets > 4 ? _validatePriceFeed(priceFeed4, stalenessPeriod4) : false;

        _initLimiter(); // U:[BAL-S-1]
    }

    function getAggregatePrice() public view override returns (int256 answer) {
        answer = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0); // U:[BAL-S-2]

        int256 answerA = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);
        if (answerA < answer) answer = answerA; // U:[BAL-S-2]

        if (numAssets > 2) {
            answerA = _getValidatedPrice(priceFeed2, stalenessPeriod2, skipCheck2);
            if (answerA < answer) answer = answerA; // U:[BAL-S-2]

            if (numAssets > 3) {
                answerA = _getValidatedPrice(priceFeed3, stalenessPeriod3, skipCheck3);
                if (answerA < answer) answer = answerA; // U:[BAL-S-2]

                if (numAssets > 4) {
                    answerA = _getValidatedPrice(priceFeed4, stalenessPeriod4, skipCheck4);
                    if (answerA < answer) answer = answerA; // U:[BAL-S-2]
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
}
