// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

contract WstETHMock is ERC20Mock {
    uint256 public stEthPerToken;

    constructor() ERC20Mock("Wrapped staked Ether", "wstETH", 18) {}

    function hackStEthPerToken(uint256 newStEthPerToken) external {
        stEthPerToken = newStEthPerToken;
    }
}
