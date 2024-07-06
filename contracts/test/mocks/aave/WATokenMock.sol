// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IWAToken} from "../../../interfaces/aave/IWAToken.sol";

contract WATokenMock is IWAToken {
    uint256 public exchangeRate;

    function hackExchangeRate(uint256 newExchangeRate) external {
        exchangeRate = newExchangeRate;
    }
}
