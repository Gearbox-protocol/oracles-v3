// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

interface ICurvePool {
    function get_virtual_price() external view returns (uint256);

    function price_oracle() external view returns (uint256);
}
