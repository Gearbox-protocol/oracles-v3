// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IBalancerWeightedPool} from "../../../interfaces/balancer/IBalancerWeightedPool.sol";

contract BalancerWeightedPoolMock is IBalancerWeightedPool {
    uint256 public override getRate;
    bytes32 public immutable override getPoolId;
    uint256 public immutable override totalSupply;
    bool public immutable actualSupplyEnabled;
    uint256[] _weights;

    constructor(bytes32 poolId, uint256 supply, bool enableActualSupply, uint256[] memory weights) {
        getPoolId = poolId;
        totalSupply = supply;
        _weights = weights;
        actualSupplyEnabled = enableActualSupply;
    }

    function getNormalizedWeights() external view override returns (uint256[] memory) {
        return _weights;
    }

    function getActualSupply() external view override returns (uint256) {
        if (!actualSupplyEnabled) revert("getActualSupply not enabled");
        return totalSupply;
    }
}
