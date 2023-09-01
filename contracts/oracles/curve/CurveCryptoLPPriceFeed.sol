// SPDX-License-Identifier: GPL-3.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedParams} from "../PriceFeedParams.sol";
import {FixedPoint} from "../../libraries/FixedPoint.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

uint256 constant WAD_OVER_USD_FEED_SCALE = 10 ** 10;

/// @title Curve crypto LP price feed
/// @dev For cryptoswap pools, aggregate is geometric mean of underlying tokens prices times the number of coins
/// @dev Older pools may be decoupled from their LP token, so constructor accepts both token and pool
contract CurveCryptoLPPriceFeed is LPPriceFeed {
    using FixedPoint for uint256;

    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.CURVE_CRYPTO_ORACLE;

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

    constructor(address addressProvider, address _token, address _pool, PriceFeedParams[3] memory priceFeeds)
        LPPriceFeed(addressProvider, _token, _pool) // U:[CRV-C-1]
        nonZeroAddress(priceFeeds[0].priceFeed) // U:[CRV-C-2]
        nonZeroAddress(priceFeeds[1].priceFeed) // U:[CRV-C-2]
    {
        priceFeed0 = priceFeeds[0].priceFeed;
        priceFeed1 = priceFeeds[1].priceFeed;
        priceFeed2 = priceFeeds[2].priceFeed;

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod1 = priceFeeds[1].stalenessPeriod;
        stalenessPeriod2 = priceFeeds[2].stalenessPeriod;

        nCoins = priceFeed2 == address(0) ? 2 : 3; // U:[CRV-C-2]

        skipCheck0 = _validatePriceFeed(priceFeed0, stalenessPeriod0);
        skipCheck1 = _validatePriceFeed(priceFeed1, stalenessPeriod1);
        skipCheck2 = nCoins == 3 ? _validatePriceFeed(priceFeed2, stalenessPeriod2) : false;

        _initLimiter(); // U:[CRV-C-1]
    }

    function getAggregatePrice() public view override returns (int256 answer) {
        answer = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0);
        uint256 product = uint256(answer) * WAD_OVER_USD_FEED_SCALE; // U:[CRV-C-2]

        answer = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);
        product = product.mulDown(uint256(answer) * WAD_OVER_USD_FEED_SCALE); // U:[CRV-C-2]

        if (nCoins == 3) {
            answer = _getValidatedPrice(priceFeed2, stalenessPeriod2, skipCheck2);
            product = product.mulDown(uint256(answer) * WAD_OVER_USD_FEED_SCALE); // U:[CRV-C-2]
        }

        answer = int256(nCoins * product.powDown(WAD / nCoins) / WAD_OVER_USD_FEED_SCALE); // U:[CRV-C-2]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return uint256(ICurvePool(lpContract).get_virtual_price()); // U:[CRV-C-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[CRV-C-1]
    }
}
