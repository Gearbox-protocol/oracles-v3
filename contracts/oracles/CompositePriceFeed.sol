// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {LibString} from "@solady/utils/LibString.sol";
import {PriceFeedParams} from "./PriceFeedParams.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Composite price feed
/// @notice Computes target asset USD price as product of target/base price times base/USD price
contract CompositePriceFeed is IPriceFeed, PriceFeedValidationTrait, SanityCheckTrait {
    using LibString for string;
    using LibString for bytes32;

    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_COMPOSITE_ORACLE";

    uint8 public constant override decimals = 8; // U:[CPF-2]
    bool public constant override skipPriceCheck = true; // U:[CPF-2]

    /// @notice Price feed that returns target asset price denominated in base asset
    address public immutable priceFeed0;
    uint32 public immutable stalenessPeriod0;
    bool public immutable skipCheck0;

    /// @notice Price feed that returns base price denominated in USD
    address public immutable priceFeed1;
    uint32 public immutable stalenessPeriod1;
    bool public immutable skipCheck1;

    /// @notice Scale of answers in target/base price feed
    int256 public immutable targetFeedScale;

    /// @dev Price feed description ticker
    bytes32 internal _descriptionTicker;

    /// @notice Constructor
    /// @param priceFeeds Array with two price feeds, where the first one returns target asset price
    ///        denominated in base asset, and the second one returns base price denominated in USD
    /// @param descriptionTicker Ticker to use in price feed description
    constructor(PriceFeedParams[2] memory priceFeeds, string memory descriptionTicker)
        nonZeroAddress(priceFeeds[0].priceFeed) // U:[CPF-1]
        nonZeroAddress(priceFeeds[1].priceFeed) // U:[CPF-1]
    {
        priceFeed0 = priceFeeds[0].priceFeed; // U:[CPF-1]
        priceFeed1 = priceFeeds[1].priceFeed; // U:[CPF-1]

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod; // U:[CPF-1]
        stalenessPeriod1 = priceFeeds[1].stalenessPeriod; // U:[CPF-1]

        targetFeedScale = int256(10 ** IPriceFeed(priceFeed0).decimals()); // U:[CPF-1]
        // target/base price feed validation is omitted because it will fail if feed has other than 8 decimals
        skipCheck0 = false; // U:[CPF-1]
        skipCheck1 = _validatePriceFeed(priceFeed1, stalenessPeriod1); // U:[CPF-1]

        _descriptionTicker = descriptionTicker.toSmallString();
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(_descriptionTicker.fromSmallString(), " composite price feed"); // U:[CPF-2]
    }

    /// @notice Returns the USD price of the target asset, computed as target/base price times base/USD price
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0); // U:[CPF-3]
        int256 answer2 = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1); // U:[CPF-3]
        answer = (answer * answer2) / targetFeedScale; // U:[CPF-3]
        return (0, answer, 0, 0, 0);
    }
}
