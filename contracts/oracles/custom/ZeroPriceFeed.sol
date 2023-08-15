// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeed.sol";

/// @title Zero price feed
/// @notice Always returns zero price as answer
contract ZeroPriceFeed is IPriceFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.ZERO_ORACLE;
    uint256 public constant override version = 3_00;
    uint8 public constant override decimals = 8;
    string public constant override description = "Zero price feed";
    bool public constant override skipPriceCheck = true;

    /// @notice Returns zero price
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 0, 0, block.timestamp, 0);
    }
}
