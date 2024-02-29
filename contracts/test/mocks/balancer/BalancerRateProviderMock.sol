// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IBalancerRateProvider} from "../../../interfaces/balancer/IBalancerStablePool.sol";

contract BalancerRateProviderMock is IBalancerRateProvider {
    uint256 public override getRate;

    constructor(uint256 rate) {
        getRate = rate;
    }
}
