// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedParams} from "../AbstractPriceFeed.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

/// @title Curve stable LP price feed
/// @dev For stableswap pools, aggregate is simply the minimum of underlying tokens prices
/// @dev Older pools may be decoupled from their LP token, so constructor accepts both token and pool
contract CurveStableLPPriceFeed is LPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public immutable override priceFeedType;

    uint16 public immutable nCoins;

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

    constructor(address addressProvider, address _token, address _pool, PriceFeedParams[4] memory priceFeeds)
        LPPriceFeed(addressProvider, _token, _pool)
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

    function getAggregatePrice() public view override returns (int256 answer, uint256 updatedAt) {
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

    function getLPExchangeRate() public view override returns (uint256) {
        return uint256(ICurvePool(lpContract).get_virtual_price());
    }

    function getScale() public pure override returns (uint256) {
        return WAD;
    }
}
