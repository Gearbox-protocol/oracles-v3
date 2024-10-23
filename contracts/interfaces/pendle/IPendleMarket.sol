// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

interface IPendleMarket {
    function observe(uint32[] calldata secondsAgos) external view returns (uint216[] memory);

    function expiry() external view returns (uint256);

    function readTokens() external view returns (address, address, address);
}
