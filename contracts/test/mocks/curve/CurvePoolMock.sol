// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";

contract CurvePoolMock is ICurvePool {
    uint256 public override get_virtual_price;
    uint256 public override price_oracle;

    function hack_virtual_price(uint256 new_virtual_price) external {
        get_virtual_price = new_virtual_price;
    }

    function hack_price_oracle(uint256 new_price_oracle) external {
        price_oracle = new_price_oracle;
    }
}
