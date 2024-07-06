// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ICToken} from "../../../interfaces/compound/ICToken.sol";

contract CTokenMock is ICToken {
    uint256 public override exchangeRateStored;

    function hackExchangeRateStored(uint256 newExchangeRateStored) external {
        exchangeRateStored = newExchangeRateStored;
    }
}
