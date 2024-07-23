// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IMellowChainlinkOracle} from "./IMellowChainlinkOracle.sol";

interface IMellowVaultConfigurator {
    function priceOracle() external view returns (IMellowChainlinkOracle);
}
