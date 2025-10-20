// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IMellowVault} from "../../../interfaces/mellow/IMellowVault.sol";
import {IMellowVaultConfigurator} from "../../../interfaces/mellow/IMellowVaultConfigurator.sol";

contract MellowVaultMock is IMellowVault {
    IMellowVault.ProcessWithdrawalsStack stack;

    IMellowVaultConfigurator public configurator;

    constructor(IMellowVaultConfigurator configurator_) {
        configurator = configurator_;
    }

    function setStack(uint256 totalValue, uint256 totalSupply) external {
        stack.totalValue = totalValue;
        stack.totalSupply = totalSupply;
    }

    function calculateStack() external view returns (IMellowVault.ProcessWithdrawalsStack memory) {
        return stack;
    }
}
