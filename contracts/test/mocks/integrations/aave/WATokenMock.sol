// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

contract WATokenMock is ERC20Mock {
    uint256 public exchangeRate;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Mock(name_, symbol_, decimals_) {}

    function hackExchangeRate(uint256 newExchangeRate) external {
        exchangeRate = newExchangeRate;
    }
}
