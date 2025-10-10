// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

interface IwstETH {
    function stETH() external view returns (address);

    function stEthPerToken() external view returns (uint256);
}
