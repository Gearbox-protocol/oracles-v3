// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title Price feed interface
interface IPriceFeed is AggregatorV3Interface {
    function priceFeedType() external view returns (PriceFeedType);
    function skipPriceCheck() external view returns (bool);
}
