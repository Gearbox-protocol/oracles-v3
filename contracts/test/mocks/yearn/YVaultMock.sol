// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IYVault} from "../../../interfaces/yearn/IYVault.sol";

contract YVaultMock is IYVault {
    address public override token;
    uint8 public override decimals;
    uint256 public override pricePerShare;

    constructor(address _token, uint8 _decimals) {
        token = _token;
        decimals = _decimals;
    }

    function hackPricePerShare(uint256 newPricePerShare) external {
        pricePerShare = newPricePerShare;
    }
}
