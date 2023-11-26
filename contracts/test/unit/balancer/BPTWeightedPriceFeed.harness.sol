// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedParams} from "../../../oracles/PriceFeedParams.sol";
import {BPTWeightedPriceFeed} from "../../../oracles/balancer/BPTWeightedPriceFeed.sol";

contract BPTWeightedPriceFeedHarness is BPTWeightedPriceFeed {
    constructor(
        address addressProvider,
        uint256 lowerBound,
        address _vault,
        address _pool,
        PriceFeedParams[] memory priceFeeds
    ) BPTWeightedPriceFeed(addressProvider, lowerBound, _vault, _pool, priceFeeds) {}

    function getWeightsArrayExposed() external view returns (uint256[] memory weights) {
        weights = _getWeightsArray();
    }

    function getBalancesArrayExposed() external view returns (uint256[] memory balances) {
        balances = _getBalancesArray();
    }
}
