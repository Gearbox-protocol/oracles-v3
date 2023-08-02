// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedParams} from "../AbstractPriceFeed.sol";
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
        PriceFeedParams[3] memory priceFeeds,
        string memory _description
    )
        AbstractCurveLPPriceFeed(addressProvider, _curvePool, _description)
        nonZeroAddress(priceFeeds[0].priceFeed)
        nonZeroAddress(priceFeeds[1].priceFeed)
    {
        priceFeed1 = priceFeeds[0].priceFeed; // F:[OCLP-1]
        priceFeed2 = priceFeeds[1].priceFeed; // F:[OCLP-1]
        priceFeed3 = priceFeeds[2].priceFeed; // F:[OCLP-1]

        stalenessPeriod1 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod2 = priceFeeds[1].stalenessPeriod;
        stalenessPeriod3 = priceFeeds[2].stalenessPeriod;

        nCoins = priceFeed3 == address(0) ? 2 : 3;
    }

    /// @dev Returns the USD price of Curve Tricrypto pool's LP token
    /// @notice Computes the LP token price as n * (prod_i(price(coin_i)))^(1/n) * virtual_price()
    function latestRoundData()
        external
        view
        virtual
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (int256 answerCurrent, uint256 updatedAtCurrent) = _getValidatedPrice(priceFeed1, stalenessPeriod1);
        uint256 product = uint256(answerCurrent) * DECIMALS / USD_FEED_DECIMALS;

        (answerCurrent, updatedAtCurrent) = _getValidatedPrice(priceFeed2, stalenessPeriod2);
        product = product.mulDown(uint256(answerCurrent) * DECIMALS / USD_FEED_DECIMALS);

        if (nCoins == 3) {
            (answerCurrent, updatedAtCurrent) = _getValidatedPrice(priceFeed2, stalenessPeriod2);
            product = product.mulDown(uint256(answerCurrent) * DECIMALS / USD_FEED_DECIMALS);
        }

        uint256 virtualPrice = _getValidatedContractValue();
        answer = int256(product.powDown(DECIMALS / nCoins).mulDown(nCoins * virtualPrice));

        answer = answer * int256(USD_FEED_DECIMALS) / int256(DECIMALS);
    }
}
