// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IBalancerVault} from "../../../interfaces/balancer/IBalancerVault.sol";

struct PoolToken {
    address token;
    uint256 balance;
}

contract BalancerVaultMock is IBalancerVault {
    mapping(bytes32 => PoolToken[]) _poolTokens;

    function hackPoolTokens(bytes32 poolId, PoolToken[] memory poolTokens) external {
        delete _poolTokens[poolId];
        uint256 len = poolTokens.length;
        if (len != 0) {
            for (uint256 i; i < len; ++i) {
                _poolTokens[poolId].push(poolTokens[i]);
            }
        }
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        override
        returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangedBlock)
    {
        PoolToken[] storage poolTokens = _poolTokens[poolId];
        uint256 len = poolTokens.length;
        if (len != 0) {
            tokens = new address[](len);
            balances = new uint256[](len);
            for (uint256 i; i < len; ++i) {
                tokens[i] = poolTokens[i].token;
                balances[i] = poolTokens[i].balance;
            }
        }
        lastChangedBlock = block.number;
    }
}
