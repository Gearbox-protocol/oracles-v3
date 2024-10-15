// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {LibString} from "@solady/utils/LibString.sol";
import {IncorrectParameterException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";

/// @title Bounded price feed
/// @notice Can be used to provide upper-bounded answers for assets that are
///         expected to have the price in a certain range, e.g. stablecoins
contract BoundedPriceFeed is IPriceFeed, SanityCheckTrait, PriceFeedValidationTrait {
    using LibString for string;
    using LibString for bytes32;

    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_BOUNDED_ORACLE";

    uint8 public constant override decimals = 8; // U:[BPF-2]
    bool public constant override skipPriceCheck = true; // U:[BPF-2]

    /// @notice Underlying price feed
    address public immutable priceFeed;
    uint32 public immutable stalenessPeriod;
    bool public immutable skipCheck;

    /// @notice Upper bound for underlying price feed answers
    int256 public immutable upperBound;

    /// @dev Price feed description ticker
    bytes32 internal _descriptionTicker;

    /// @notice Constructor
    /// @param _priceFeed Underlying price feed
    /// @param _stalenessPeriod Underlying price feed staleness period, must be non-zero unless it performs own checks
    /// @param _upperBound Upper bound for underlying price feed answers
    /// @param descriptionTicker Ticker to use in price feed description
    constructor(address _priceFeed, uint32 _stalenessPeriod, int256 _upperBound, string memory descriptionTicker)
        nonZeroAddress(_priceFeed) // U:[BPF-1]
    {
        if (_upperBound <= 0) revert IncorrectParameterException(); // U:[BPF-1]
        priceFeed = _priceFeed; // U:[BPF-1]
        stalenessPeriod = _stalenessPeriod; // U:[BPF-1]
        skipCheck = _validatePriceFeed(priceFeed, stalenessPeriod); // U:[BPF-1]
        upperBound = _upperBound; // U:[BPF-1]
        _descriptionTicker = descriptionTicker.toSmallString();
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(_descriptionTicker.fromSmallString(), " bounded price feed"); // U:[BPF-2]
    }

    /// @notice Serialized price feed parameters
    function serialize() external view returns (bytes memory) {
        return abi.encode(upperBound);
    }

    /// @notice Returns the upper-bounded USD price of the token
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck); // U:[BPF-3]
        return (0, _upperBoundValue(answer), 0, 0, 0); // U:[BPF-3]
    }

    /// @dev Upper-bounds given value
    function _upperBoundValue(int256 value) internal view returns (int256) {
        return (value > upperBound) ? upperBound : value;
    }
}
