// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AbstractPriceFeed} from "./AbstractPriceFeed.sol";
import {PriceFeedType} from "../interfaces/IPriceFeed.sol";

/// @title Zero price feed
/// @notice Always returns zero price as answer
contract ZeroPriceFeed is AbstractPriceFeed {
    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.ZERO_ORACLE;
    string public constant override description = "Zero price feed";

    /// @notice Returns zero price
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 0, 0, block.timestamp, 0);
    }
}
