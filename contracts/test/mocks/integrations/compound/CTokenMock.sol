// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

contract CTokenMock is ERC20Mock {
    uint256 public exchangeRateStored;

    constructor(string memory name_, string memory symbol_) ERC20Mock(name_, symbol_, 8) {}

    function hackExchangeRateStored(uint256 newExchangeRateStored) external {
        exchangeRateStored = newExchangeRateStored;
    }
}
