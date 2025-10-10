// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IMellowChainlinkOracle} from "../../../interfaces/mellow/IMellowChainlinkOracle.sol";
import {IMellowVaultConfigurator} from "../../../interfaces/mellow/IMellowVaultConfigurator.sol";

contract MellowVaultConfiguratorMock is IMellowVaultConfigurator {
    IMellowChainlinkOracle public priceOracle;

    constructor(IMellowChainlinkOracle priceOracle_) {
        priceOracle = priceOracle_;
    }
}
