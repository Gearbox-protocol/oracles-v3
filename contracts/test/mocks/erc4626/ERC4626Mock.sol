// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract ERC4626Mock is ERC4626 {
    uint256 public pricePerShare;

    constructor(address asset, string memory name, string memory symbol) ERC20(name, symbol) ERC4626(IERC20(asset)) {}

    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        return shares * pricePerShare / 10 ** decimals();
    }

    function hackPricePerShare(uint256 newPricePerShare) external {
        pricePerShare = newPricePerShare;
    }
}
