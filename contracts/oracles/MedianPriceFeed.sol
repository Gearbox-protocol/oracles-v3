// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {LibString} from "@solady/utils/LibString.sol";
import {PriceFeedParams} from "./PriceFeedParams.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {PriceFeedValidationTrait} from "../traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Median price feed
/// @notice Computes target asset USD price as median of up to three individual price feeds
contract MedianPriceFeed is IPriceFeed, PriceFeedValidationTrait, SanityCheckTrait {
    using LibString for string;
    using LibString for bytes32;

    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PRICE_FEED::MEDIAN";

    uint8 public constant override decimals = 8; // U:[MPF-2]
    bool public constant override skipPriceCheck = true; // U:[MPF-2]

    /// @notice First price feed (must be non-zero)
    address public immutable priceFeed0;
    uint32 public immutable stalenessPeriod0;
    bool public immutable skipCheck0;

    /// @notice Second price feed (optional; zero address means unused)
    address public immutable priceFeed1;
    uint32 public immutable stalenessPeriod1;
    bool public immutable skipCheck1;

    /// @notice Third price feed (optional; zero address means unused)
    address public immutable priceFeed2;
    uint32 public immutable stalenessPeriod2;
    bool public immutable skipCheck2;

    /// @notice Number of configured price feeds (1, 2, or 3)
    uint16 public immutable nFeeds;

    /// @dev Price feed description ticker
    bytes32 internal _descriptionTicker;

    /// @notice Constructor
    /// @param priceFeeds Array with up to three price feeds; trailing zero addresses are ignored,
    ///        and non-zero feeds must be contiguous from the start
    /// @param descriptionTicker Ticker to use in price feed description
    constructor(PriceFeedParams[3] memory priceFeeds, string memory descriptionTicker)
        nonZeroAddress(priceFeeds[0].priceFeed) // U:[MPF-1]

    {
        priceFeed0 = priceFeeds[0].priceFeed; // U:[MPF-1]
        priceFeed1 = priceFeeds[1].priceFeed; // U:[MPF-1]
        priceFeed2 = priceFeeds[2].priceFeed; // U:[MPF-1]

        uint16 _nFeeds = 1;

        if (priceFeed1 != address(0)) _nFeeds++; // U:[MPF-1]
        if (priceFeed2 != address(0)) _nFeeds++; // U:[MPF-1]

        nFeeds = _nFeeds; // U:[MPF-1]

        stalenessPeriod0 = priceFeeds[0].stalenessPeriod; // U:[MPF-1]
        stalenessPeriod1 = nFeeds > 1 ? priceFeeds[1].stalenessPeriod : 0; // U:[MPF-1]
        stalenessPeriod2 = nFeeds > 2 ? priceFeeds[2].stalenessPeriod : 0; // U:[MPF-1]

        _descriptionTicker = descriptionTicker.toSmallString();
        skipCheck0 = _validatePriceFeedMetadata(priceFeed0, stalenessPeriod0); // U:[MPF-1]
        skipCheck1 = nFeeds > 1 ? _validatePriceFeedMetadata(priceFeed1, stalenessPeriod1) : false; // U:[MPF-1]
        skipCheck2 = nFeeds > 2 ? _validatePriceFeedMetadata(priceFeed2, stalenessPeriod2) : false; // U:[MPF-1]
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(_descriptionTicker.fromSmallString(), " median price feed"); // U:[MPF-2]
    }

    /// @notice Empty state serialization
    function serialize() external pure override returns (bytes memory) {}

    /// @dev Returns the median of `answers` (single value, average of two, or middle of three)
    function _median(int256[] memory answers) internal view returns (int256 median) {
        if (nFeeds == 1) return answers[0];
        if (nFeeds == 2) return (answers[0] + answers[1]) / 2;
        if (nFeeds == 3) {
            (answers[0], answers[1]) = (answers[0] < answers[1] ? (answers[0], answers[1]) : (answers[1], answers[0]));
            (answers[1], answers[2]) = (answers[1] < answers[2] ? (answers[1], answers[2]) : (answers[2], answers[1]));
            (answers[0], answers[1]) = (answers[0] < answers[1] ? (answers[0], answers[1]) : (answers[1], answers[0]));
            return answers[1];
        }
    }

    /// @dev Returns the minimum of the first `nFeeds` timestamps
    function _min(uint256[] memory updatedAt) internal view returns (uint256 min) {
        min = type(uint256).max;
        for (uint16 i = 0; i < nFeeds; i++) {
            if (updatedAt[i] < min) min = updatedAt[i];
        }
        return min;
    }

    /// @notice Returns the USD price of the token as the median of configured price feeds,
    ///         with `updatedAt` equal to the earliest underlying update timestamp
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        int256[] memory answers = new int256[](nFeeds);
        uint256[] memory updatedAts = new uint256[](nFeeds);

        (answers[0], updatedAts[0]) = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0); // U:[MPF-3]
        if (nFeeds > 1) (answers[1], updatedAts[1]) = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1); // U:[MPF-3]
        if (nFeeds > 2) (answers[2], updatedAts[2]) = _getValidatedPrice(priceFeed2, stalenessPeriod2, skipCheck2); // U:[MPF-3]

        int256 answer = _median(answers); // U:[MPF-3,4]
        uint256 updatedAt = _min(updatedAts); // U:[MPF-3]

        return (0, answer, 0, updatedAt, 0);
    }
}
