// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {PriceFeedValidationTrait} from "../traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @dev Window size in bps, used to compute upper bound given lower bound
uint256 constant WINDOW_SIZE = 200;

/// @dev Number of seconds in a year
uint256 constant SECONDS_PER_YEAR = 365 days;

/// @title Fixed rate window price feed
/// @notice Bounds underlying price feed returned value within a window that grows at set rate
contract FixedRateWindowPriceFeed is IPriceFeed, Ownable, PriceFeedValidationTrait, SanityCheckTrait {
    using LibString for string;
    using LibString for bytes32;

    /// @notice Thrown when growth rate exceeds the configured maximum
    error InvalidGrowthRateException();

    /// @notice Thrown when underlying answer is below the lower bound, or when new bounds
    ///         do not contain the current underlying answer
    error ValueOutOfBoundsException();

    /// @notice Emitted when growth rate and bounds are updated
    event SetRateAndBounds(uint16 growthRate, uint256 lowerBoundBase, uint256 upperBound);

    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PRICE_FEED::FIXED_RATE_WINDOW";

    uint8 public constant override decimals = 8; // U:[FRWPF-2]
    bool public constant override skipPriceCheck = true; // U:[FRWPF-2]

    /// @notice Underlying price feed
    address public immutable priceFeed;
    uint32 public immutable stalenessPeriod;
    bool public immutable skipCheck;

    /// @notice Annual growth rate of the lower bound, in bps (`PERCENTAGE_FACTOR` = 100%)
    uint16 public growthRate;

    /// @notice Lower bound at `timestampLU`
    uint256 public lowerBoundBase;

    /// @notice Timestamp at which `lowerBoundBase` was last updated
    uint256 public timestampLU;

    /// @notice Maximum allowed growth rate
    uint16 public immutable maxGrowthRate;

    /// @dev Price feed description ticker
    bytes32 internal _descriptionTicker;

    /// @notice Constructor
    /// @param _priceFeed Underlying price feed
    /// @param _stalenessPeriod Underlying price feed staleness period
    /// @param growthRateInitial Initial annual growth rate of the lower bound, in bps
    /// @param lowerBoundInitial Initial lower bound; current underlying answer must lie within
    ///        `[lowerBoundInitial, lowerBoundInitial * (1 + WINDOW_SIZE)]`
    /// @param _maxGrowthRate Maximum allowed growth rate
    /// @param descriptionTicker Ticker to use in price feed description
    constructor(
        address _priceFeed,
        uint32 _stalenessPeriod,
        uint16 growthRateInitial,
        uint256 lowerBoundInitial,
        uint16 _maxGrowthRate,
        string memory descriptionTicker
    ) nonZeroAddress(_priceFeed) {
        // U:[FRWPF-1]
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        maxGrowthRate = _maxGrowthRate;
        skipCheck = _validatePriceFeedMetadata(priceFeed, stalenessPeriod);

        _setRateAndBounds(growthRateInitial, lowerBoundInitial);

        _descriptionTicker = descriptionTicker.toSmallString();
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(_descriptionTicker.fromSmallString(), " fixed rate window price feed"); // U:[FRWPF-2]
    }

    /// @notice Empty state serialization
    function serialize() external pure override returns (bytes memory) {}

    /// @dev Lower bound grown from `lowerBoundBase` at `growthRate` since `timestampLU`
    function _lowerBound() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - timestampLU;
        uint256 growth = growthRate * timeElapsed / SECONDS_PER_YEAR;

        return lowerBoundBase * (PERCENTAGE_FACTOR + growth) / PERCENTAGE_FACTOR;
    }

    /// @dev Upper bound as lower bound plus `WINDOW_SIZE` bps
    function _upperBound(uint256 _lb) internal pure returns (uint256) {
        return _lb * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR;
    }

    /// @notice Returns the USD price of the token, reverting if below the growing lower bound
    ///         and capping at the upper bound (lower bound + `WINDOW_SIZE`)
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        (int256 answer, uint256 updatedAt) = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck); // U:[FRWPF-3]

        uint256 lb = _lowerBound(); // U:[FRWPF-3]
        uint256 ub = _upperBound(lb); // U:[FRWPF-3]

        if (uint256(answer) < lb) revert ValueOutOfBoundsException(); // U:[FRWPF-3]
        if (uint256(answer) > ub) answer = int256(ub); // U:[FRWPF-3]

        return (0, answer, 0, updatedAt, 0);
    }

    /// @dev Sets growth rate and lower bound base; current underlying answer must lie within the new window
    function _setRateAndBounds(uint16 _growthRate, uint256 _lowerBoundBase) internal {
        if (_growthRate > maxGrowthRate) revert InvalidGrowthRateException(); // U:[FRWPF-1,4]

        (int256 answer,) = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck); // U:[FRWPF-1,4]

        uint256 ub = _upperBound(_lowerBoundBase);

        if (uint256(answer) < _lowerBoundBase || uint256(answer) > ub) {
            revert ValueOutOfBoundsException(); // U:[FRWPF-1,4]
        }

        growthRate = _growthRate; // U:[FRWPF-1,4]
        lowerBoundBase = _lowerBoundBase; // U:[FRWPF-1,4]
        timestampLU = block.timestamp; // U:[FRWPF-1,4]

        emit SetRateAndBounds(growthRate, lowerBoundBase, ub); // U:[FRWPF-4]
    }

    /// @notice Updates growth rate and lower bound; callable only by the owner
    /// @param _growthRate New annual growth rate of the lower bound, in bps
    /// @param _lowerBoundBase New lower bound at the current timestamp
    function setRateAndBounds(uint16 _growthRate, uint256 _lowerBoundBase) external onlyOwner {
        _setRateAndBounds(_growthRate, _lowerBoundBase); // U:[FRWPF-4]
    }
}
