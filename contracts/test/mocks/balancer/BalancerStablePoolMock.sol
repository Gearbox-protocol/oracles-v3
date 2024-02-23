// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {BalancerRateProviderMock} from "./BalancerRateProviderMock.sol";
import {IBalancerStablePool} from "../../../interfaces/balancer/IBalancerStablePool.sol";

contract BalancerStablePoolMock is IBalancerStablePool {
    uint256 public override getRate;

    mapping(address => uint256) public getTokenRate;

    address[] public rateProviders;

    address public getVault;
    bytes32 public getPoolId;

    constructor(address balancerVault, bytes32 poolId) {
        getVault = balancerVault;
        getPoolId = poolId;
    }

    function hackRate(uint256 newRate) external {
        getRate = newRate;
    }

    function getRateProviders() external view returns (address[] memory) {
        return rateProviders;
    }

    function hackRateProviders(uint256[] memory rates) external {
        rateProviders = new address[](0);

        for (uint256 i = 0; i < rates.length; ++i) {
            address rateProvider = address(new BalancerRateProviderMock(rates[i]));
            rateProviders.push(rateProvider);
        }
    }
}
