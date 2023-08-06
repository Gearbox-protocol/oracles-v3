// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AbstractPriceFeed, PriceFeedParams} from "./AbstractPriceFeed.sol";
import {PriceFeedType} from "../interfaces/IPriceFeed.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title Composite price feed
/// @notice Computes target asset USD price as product of target/base price times base/USD price
contract CompositePriceFeed is AbstractPriceFeed, SanityCheckTrait {
    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.COMPOSITE_ORACLE;

    /// @notice Price feed that returns target asset price denominated in base asset
    address public immutable priceFeed0;
    uint32 public immutable stalenessPeriod0;

    /// @notice Price feed that returns base price denominated in USD
    address public immutable priceFeed1;
    uint32 public immutable stalenessPeriod1;
    bool skipCheck1;

    /// @notice Scale of answers in target/base price feed
    int256 public immutable targetFeedScale;

    /// @notice Constructor
    /// @param priceFeeds Array with two price feeds, where the first one returns target asset price
    ///        denominated in base asset, and the second one returns base price denominated in USD
    constructor(PriceFeedParams[2] memory priceFeeds)
        nonZeroAddress(priceFeeds[0].priceFeed)
        nonZeroAddress(priceFeeds[1].priceFeed)
    {
        priceFeed0 = priceFeeds[0].priceFeed;
        priceFeed1 = priceFeeds[1].priceFeed;

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod;
        stalenessPeriod1 = priceFeeds[1].stalenessPeriod;

        targetFeedScale = int256(10 ** AggregatorV3Interface(priceFeed0).decimals());
        // target/base price feed validation is omitted because it will fail if feed has other than 8 decimals
        skipCheck1 = _validatePriceFeed(priceFeed1, stalenessPeriod1);
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string(
            abi.encodePacked(
                AggregatorV3Interface(priceFeed0).description(),
                " * ",
                AggregatorV3Interface(priceFeed1).description(),
                " composite price feed"
            )
        );
    }

    /// @notice Returns the USD price of the target asset, computed as target/base price times base/USD price
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getValidatedPrice(priceFeed0, stalenessPeriod0, false);
        (int256 answer2,) = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);
        answer = (answer * answer2) / targetFeedScale;
        return (0, answer, 0, updatedAt, 0);
    }
}
