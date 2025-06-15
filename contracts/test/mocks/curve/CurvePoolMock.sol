// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";

contract CurvePoolMock is ICurvePool {
    uint256 public override get_virtual_price;
    uint256 internal price_oracle_value;

    bool public withIndex = false;

    function hack_virtual_price(uint256 new_virtual_price) external {
        get_virtual_price = new_virtual_price;
    }

    function hack_price_oracle(uint256 new_price_oracle) external {
        price_oracle_value = new_price_oracle;
    }

    function hack_withIndex(bool new_withIndex) external {
        withIndex = new_withIndex;
    }

    function price_oracle() external view returns (uint256) {
        if (withIndex) {
            revert();
        }
        return price_oracle_value;
    }

    function price_oracle(uint256 index) external view returns (uint256) {
        if (!withIndex || index != 0) {
            revert();
        }
        return price_oracle_value;
    }
}
