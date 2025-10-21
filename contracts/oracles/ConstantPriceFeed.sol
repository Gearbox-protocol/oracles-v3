// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {LibString} from "@solady/utils/LibString.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Constant price feed
/// @notice A simple price feed that returns a constant value set in the constructor
contract ConstantPriceFeed is IPriceFeed, SanityCheckTrait {
    using LibString for string;
    using LibString for bytes32;

    /// @notice Contract version
    uint256 public constant override version = 3_10;

    /// @notice Contract type
    bytes32 public constant override contractType = "PRICE_FEED::CONSTANT";

    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true;

    /// @notice The constant price value to return
    int256 public immutable price;

    bytes32 internal descriptionTicker;

    /// @notice Constructor
    /// @param _price The constant price value to return (with 8 decimals)
    /// @param _descriptionTicker Short form description
    constructor(int256 _price, string memory _descriptionTicker) {
        if (_price <= 0) revert IncorrectPriceException();

        price = _price;
        descriptionTicker = _descriptionTicker.toSmallString();
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(descriptionTicker.fromSmallString(), " constant price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() external view override returns (bytes memory) {
        return abi.encode(price);
    }

    /// @notice Returns the constant USD price of the token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        return (0, price, 0, block.timestamp, 0);
    }
}
