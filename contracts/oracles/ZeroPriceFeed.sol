// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

/// @title Zero price feed
/// @notice Always returns zero price as answer
contract ZeroPriceFeed is IPriceFeed {
    uint256 public constant override version = 3_11;
    bytes32 public constant override contractType = "PRICE_FEED::ZERO";

    uint8 public constant override decimals = 8; // U:[ZPF-1]
    string public constant override description = "Zero price feed"; // U:[ZPF-1]
    bool public constant override skipPriceCheck = true; // U:[ZPF-1]

    /// @notice Empty state serialization
    function serialize() external pure override returns (bytes memory) {}

    /// @notice Returns zero price
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 0, 0, block.timestamp, 0); // U:[ZPF-2]
    }
}
