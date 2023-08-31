// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IwstETH} from "../../../interfaces/lido/IwstETH.sol";

contract WstETHMock is IwstETH {
    address public override stETH;
    uint256 public override stEthPerToken;

    constructor(address _stETH) {
        stETH = _stETH;
    }

    function hackStEthPerToken(uint256 newStEthPerToken) external {
        stEthPerToken = newStEthPerToken;
    }
}
