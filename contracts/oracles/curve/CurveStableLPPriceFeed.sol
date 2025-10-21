// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedParams} from "../PriceFeedParams.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Curve stable LP price feed
/// @dev For stableswap pools, aggregate is simply the minimum of underlying tokens prices
/// @dev Older pools may be decoupled from their LP token, so constructor accepts both token and pool
contract CurveStableLPPriceFeed is LPPriceFeed {
    uint256 public constant override version = 3_11;
    bytes32 public constant override contractType = "PRICE_FEED::CURVE_STABLE";

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

    constructor(
        address _owner,
        uint256 _lowerBound,
        address _token,
        address _pool,
        PriceFeedParams[4] memory priceFeeds
    )
        LPPriceFeed(_owner, _token, _pool) // U:[CRV-S-1]
        nonZeroAddress(priceFeeds[0].priceFeed) // U:[CRV-S-2]
        nonZeroAddress(priceFeeds[1].priceFeed) // U:[CRV-S-2]
    {
        priceFeed0 = priceFeeds[0].priceFeed;
        priceFeed1 = priceFeeds[1].priceFeed;
        priceFeed2 = priceFeeds[2].priceFeed;
        priceFeed3 = priceFeeds[3].priceFeed;

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod1 = priceFeeds[1].stalenessPeriod;
        stalenessPeriod2 = priceFeeds[2].stalenessPeriod;
        stalenessPeriod3 = priceFeeds[3].stalenessPeriod;

        nCoins = priceFeed2 == address(0) ? 2 : (priceFeed3 == address(0) ? 3 : 4); // U:[CRV-S-2]

        skipCheck0 = _validatePriceFeedMetadata(priceFeed0, stalenessPeriod0);
        skipCheck1 = _validatePriceFeedMetadata(priceFeed1, stalenessPeriod1);
        skipCheck2 = nCoins > 2 ? _validatePriceFeedMetadata(priceFeed2, stalenessPeriod2) : false;
        skipCheck3 = nCoins > 3 ? _validatePriceFeedMetadata(priceFeed3, stalenessPeriod3) : false;

        _setLimiter(_lowerBound); // U:[CRV-S-1]
    }

    function getAggregatePriceAndTimestamp() public view override returns (int256 answer, uint256 updatedAt) {
        (answer, updatedAt) = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0); // U:[CRV-S-2]

        (int256 answer2, uint256 updatedAt2) = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);
        (answer, updatedAt) = _agg(answer, updatedAt, answer2, updatedAt2); // U:[CRV-S-2]

        if (nCoins > 2) {
            (answer2, updatedAt2) = _getValidatedPrice(priceFeed2, stalenessPeriod2, skipCheck2);
            (answer, updatedAt) = _agg(answer, updatedAt, answer2, updatedAt2); // U:[CRV-S-2]

            if (nCoins > 3) {
                (answer2, updatedAt2) = _getValidatedPrice(priceFeed3, stalenessPeriod3, skipCheck3);
                (answer, updatedAt) = _agg(answer, updatedAt, answer2, updatedAt2); // U:[CRV-S-2]
            }
        }
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return uint256(ICurvePool(lpContract).get_virtual_price()); // U:[CRV-S-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[CRV-S-1]
    }

    function _agg(int256 answer1, uint256 updatedAt1, int256 answer2, uint256 updatedAt2)
        internal
        view
        returns (int256 answer, uint256 updatedAt)
    {
        return (answer1 < answer2 ? answer1 : answer2, updatedAt1 < updatedAt2 ? updatedAt1 : updatedAt2);
    }
}
