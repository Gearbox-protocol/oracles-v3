// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKodiakIsland is IERC20 {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getUnderlyingBalancesAtPrice(uint160 sqrtPriceRatioX96)
        external
        view
        returns (uint256 balance0, uint256 balance1);
}
