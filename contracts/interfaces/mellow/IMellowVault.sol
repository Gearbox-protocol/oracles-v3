// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {IMellowVaultConfigurator} from "./IMellowVaultConfigurator.sol";

interface IMellowVault {
    struct ProcessWithdrawalsStack {
        address[] tokens;
        uint128[] ratiosX96;
        uint256[] erc20Balances;
        uint256 totalSupply;
        uint256 totalValue;
        uint256 ratiosX96Value;
        uint256 timestamp;
        uint256 feeD9;
        bytes32 tokensHash;
    }

    function calculateStack() external view returns (ProcessWithdrawalsStack memory s);

    function configurator() external view returns (IMellowVaultConfigurator);
}
