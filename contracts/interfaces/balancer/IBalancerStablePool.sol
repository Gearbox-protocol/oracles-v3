// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

interface IBalancerRateProvider {
    function getRate() external view returns (uint256);
}

interface IBalancerStablePool is IBalancerRateProvider {
    function getPoolId() external view returns (bytes32);

    function getVault() external view returns (address);

    function getRateProviders() external view returns (address[] memory);
}
