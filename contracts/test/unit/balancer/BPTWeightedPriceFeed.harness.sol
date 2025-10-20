// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {PriceFeedParams} from "../../../oracles/PriceFeedParams.sol";
import {BPTWeightedPriceFeed} from "../../../oracles/balancer/BPTWeightedPriceFeed.sol";

contract BPTWeightedPriceFeedHarness is BPTWeightedPriceFeed {
    constructor(address _owner, uint256 lowerBound, address _vault, address _pool, PriceFeedParams[] memory priceFeeds)
        BPTWeightedPriceFeed(_owner, lowerBound, _vault, _pool, priceFeeds)
    {}

    function getWeightsArrayExposed() external view returns (uint256[] memory weights) {
        weights = _getWeightsArray();
    }

    function getBalancesArrayExposed() external view returns (uint256[] memory balances) {
        balances = _getBalancesArray();
    }
}
