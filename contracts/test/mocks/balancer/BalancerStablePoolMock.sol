// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IBalancerStablePool} from "../../../interfaces/balancer/IBalancerStablePool.sol";

contract BalancerStablePoolMock is IBalancerStablePool {
    uint256 public override getRate;

    function hackRate(uint256 newRate) external {
        getRate = newRate;
    }
}
