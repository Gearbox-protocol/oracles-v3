// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IMellowVault} from "../../../interfaces/mellow/IMellowVault.sol";

contract MellowVaultMock is IMellowVault {
    IMellowVault.ProcessWithdrawalsStack stack;

    constructor() {}

    function setStack(uint256 totalValue, uint256 totalSupply) external {
        stack.totalValue = totalValue;
        stack.totalSupply = totalSupply;
    }

    function calculateStack() external view returns (IMellowVault.ProcessWithdrawalsStack memory) {
        return stack;
    }
}
