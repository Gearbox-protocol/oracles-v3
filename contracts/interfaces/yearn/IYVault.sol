// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

interface IYVault {
    function token() external view returns (address);

    function decimals() external view returns (uint8);

    function pricePerShare() external view returns (uint256);
}
