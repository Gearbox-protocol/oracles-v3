// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {LibString} from "@solady/utils/LibString.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {IMakinaSharePriceOracle} from "../../interfaces/makina/IMakinaSharePriceOracle.sol";

/// @title Makina Oracle Wrapper
/// @notice A Chainlink-interface wrapper for Makina share price oracle
contract MakinaOracleWrapper is IPriceFeed, SanityCheckTrait {
    using LibString for string;
    using LibString for bytes32;

    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PRICE_FEED::MAKINA_WRAPPER";

    uint8 public immutable decimals;
    bool public constant override skipPriceCheck = false;

    /// @notice Underlying price feed
    address public immutable makinaSharePriceOracle;

    bytes32 internal _descriptionTicker;

    /// @notice Constructor
    /// @param _makinaSharePriceOracle Makina share price oracle
    /// @param descriptionTicker Ticker to use in price feed description
    constructor(address _makinaSharePriceOracle, string memory descriptionTicker)
        nonZeroAddress(_makinaSharePriceOracle)
    {
        makinaSharePriceOracle = _makinaSharePriceOracle;
        _descriptionTicker = descriptionTicker.toSmallString();
        decimals = IPriceFeed(makinaSharePriceOracle).decimals();
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(_descriptionTicker.fromSmallString(), " Makina share price wrapper");
    }

    /// @notice Serialized price feed parameters
    function serialize() external view override returns (bytes memory) {
        return abi.encode(makinaSharePriceOracle);
    }

    /// @notice Returns the upper-bounded USD price of the token
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        int256 answer = int256(IMakinaSharePriceOracle(makinaSharePriceOracle).getSharePrice());
        return (0, answer, 0, block.timestamp, 0);
    }
}
