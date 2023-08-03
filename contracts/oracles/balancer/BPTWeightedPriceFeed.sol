// SPDX-License-Identifier: GPL-3.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {FixedPoint} from "../../libraries/FixedPoint.sol";
import {BPTWeightedPriceFeedSetup} from "./BPTWeightedPriceFeedSetup.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {IBalancerV2VaultGetters} from "../../interfaces/balancer/IBalancerV2Vault.sol";
import {IBalancerWeightedPool} from "../../interfaces/balancer/IBalancerWeightedPool.sol";

uint256 constant RANGE_WIDTH = 200; // 2%
uint256 constant USD_FEED_SCALE = 10 ** 8;

/// @title Balancer weighted pool token price feed
contract BPTWeightedPriceFeed is BPTWeightedPriceFeedSetup, LPPriceFeed {
    using FixedPoint for uint256;

    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.BALANCER_WEIGHTED_LP_ORACLE;

    constructor(address addressProvider, address _balancerVault, address _balancerPool, address[] memory priceFeeds)
        LPPriceFeed(addressProvider, _balancerPool, RANGE_WIDTH)
        BPTWeightedPriceFeedSetup(_balancerVault, _balancerPool, priceFeeds)
    {
        _initLimiter();
    }

    /// @dev Returns the price of a single BPT in USD (with 8 decimals)
    /// @notice BPT price is computed as k * sum((p_i / w_i) ^ w_i) / S
    /// @notice Also does limiter checks on k / S, since this value must growing in a stable way from fees
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (uint256 invariantOverSupply, uint256[] memory weights) = _getInvariantOverSupplyAndWeights();

        address[] memory priceFeeds = _getPriceFeedsArray();

        uint256 weightedPrice = FixedPoint.ONE;
        uint256 currentBase = FixedPoint.ONE;

        for (uint256 i = 0; i < numAssets;) {
            // TODO: don't skip price check
            (answer, updatedAt) = _getValidatedPrice(priceFeeds[i], 0, true); // F: [OBWLP-3,4]

            answer = (answer * int256(WAD)) / int256(USD_FEED_SCALE);

            currentBase = currentBase.mulDown(uint256(answer).divDown(weights[i]));

            if (i == numAssets - 1 || weights[i] != weights[i + 1]) {
                weightedPrice = weightedPrice.mulDown(currentBase.powDown(weights[i])); // F: [OBWLP-3,4]
                currentBase = FixedPoint.ONE;
            }

            unchecked {
                ++i;
            }
        }

        answer = int256(invariantOverSupply.mulDown(weightedPrice)); // F: [OBWLP-3,4]

        answer = (answer * int256(USD_FEED_SCALE)) / int256(WAD); // F: [OBWLP-3,4]

        return (0, answer, 0, updatedAt, 0);
    }

    function getInvariantOverSupply() external view returns (uint256) {
        return _getLPExchangeRate();
    }

    function _getLPExchangeRate() internal view override returns (uint256 value) {
        (value,) = _getInvariantOverSupplyAndWeights();
    }

    function _getInvariantOverSupplyAndWeights()
        internal
        view
        returns (uint256 invariantOverSupply, uint256[] memory weights)
    {
        (, uint256[] memory balances,) = balancerVault.getPoolTokens(poolId);
        weights = _getWeightsArray();
        balances = _alignAndScaleBalanceArray(balances);
        invariantOverSupply = _computeInvariantOverSupply(balances, weights);
    }

    /// @dev Returns the supply of BPT token
    function _getBPTSupply() internal view returns (uint256 supply) {
        try balancerPool.getActualSupply() returns (uint256 actualSupply) {
            supply = actualSupply;
        } catch {
            supply = balancerPool.totalSupply();
        }
    }

    /// @dev Returns the Balancer pool invariant divided by BPT supply
    function _computeInvariantOverSupply(uint256[] memory balances, uint256[] memory weights)
        internal
        view
        returns (uint256)
    {
        uint256 k = _computeInvariant(balances, weights);
        uint256 supply = _getBPTSupply();

        return k.divDown(supply);
    }

    /// @dev Returns the Balancer pool invariant
    /// @notice Computes the invariant in a way that optimizes the number
    ///         of exponentiations, which are gas-intensive
    function _computeInvariant(uint256[] memory balances, uint256[] memory weights) internal pure returns (uint256 k) {
        k = FixedPoint.ONE;
        uint256 currentBase = FixedPoint.ONE;

        uint256 len = balances.length;

        for (uint256 i = 0; i < len;) {
            currentBase = currentBase.mulDown(balances[i]);

            if (i == len - 1 || weights[i] != weights[i + 1]) {
                k = k.mulDown(currentBase.powDown(weights[i])); // F: [OBWLP-3,4]
                currentBase = FixedPoint.ONE;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the balance array sorted in the order of increasing asset weights
    function _alignAndScaleBalanceArray(uint256[] memory balances)
        internal
        view
        returns (uint256[] memory sortedBalances)
    {
        uint256 len = balances.length;

        sortedBalances = new uint256[](len);

        sortedBalances[0] = (balances[index0] * WAD) / (10 ** decimals0);
        sortedBalances[1] = (balances[index1] * WAD) / (10 ** decimals1);
        if (len >= 3) {
            sortedBalances[2] = (balances[index2] * WAD) / (10 ** decimals2);
        }
        if (len >= 4) {
            sortedBalances[3] = (balances[index3] * WAD) / (10 ** decimals3);
        }
        if (len >= 5) {
            sortedBalances[4] = (balances[index4] * WAD) / (10 ** decimals4);
        }
        if (len >= 6) {
            sortedBalances[5] = (balances[index5] * WAD) / (10 ** decimals5);
        }
        if (len >= 7) {
            sortedBalances[6] = (balances[index6] * WAD) / (10 ** decimals6);
        }
        if (len >= 8) {
            sortedBalances[7] = (balances[index7] * WAD) / (10 ** decimals7);
        }
    }
}
