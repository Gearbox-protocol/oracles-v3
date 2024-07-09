// SPDX-License-Identifier: GPL-3.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedParams} from "../PriceFeedParams.sol";
import {FixedPoint} from "../../libraries/FixedPoint.sol";

import {IBalancerVault} from "../../interfaces/balancer/IBalancerVault.sol";
import {IBalancerWeightedPool} from "../../interfaces/balancer/IBalancerWeightedPool.sol";

uint256 constant WAD_OVER_USD_FEED_SCALE = 10 ** 10;

/// @title Balancer weighted pool token price feed
/// @notice Weighted Balancer pools LP tokens price feed.
///         BPTs are priced according to the formula `k * prod((p_i / w_i) ^ w_i) / S`, where `k` is pool's invariant,
///         `S` is pool's LP token total supply, `w_i` and `p_i` are `i`-th asset's weight and price respectively.
///         Pool's invariant, in turn, equals `prod(b_i ^ w_i)`, where `b_i` is pool's balance of `i`-th asset.
///         Bounding logic is applied to `n * k / S` which can be considered BPT's exchange rate that should grow slowly
///         over time as fees accrue.
/// @dev Severe gas optimizations have been made:
///      * Many variables saved as immutable which reduces the number of external calls and storage reads
///      * Variables are stored and processed in the order of ascending weights, which allows to reduce
///        the number of fixed point exponentiations in case some assets have identical weights
/// @dev This contract must not be used to price managed pools that allow to change their weights/tokens
contract BPTWeightedPriceFeed is LPPriceFeed {
    using FixedPoint for uint256;

    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.BALANCER_WEIGHTED_LP_ORACLE;

    /// @notice Balancer vault address
    address public immutable vault;

    /// @notice Balancer pool ID
    bytes32 public immutable poolId;

    uint256 public immutable numAssets;

    address public immutable priceFeed0;
    address public immutable priceFeed1;
    address public immutable priceFeed2;
    address public immutable priceFeed3;
    address public immutable priceFeed4;
    address public immutable priceFeed5;
    address public immutable priceFeed6;
    address public immutable priceFeed7;

    uint32 public immutable stalenessPeriod0;
    uint32 public immutable stalenessPeriod1;
    uint32 public immutable stalenessPeriod2;
    uint32 public immutable stalenessPeriod3;
    uint32 public immutable stalenessPeriod4;
    uint32 public immutable stalenessPeriod5;
    uint32 public immutable stalenessPeriod6;
    uint32 public immutable stalenessPeriod7;

    bool public immutable skipCheck0;
    bool public immutable skipCheck1;
    bool public immutable skipCheck2;
    bool public immutable skipCheck3;
    bool public immutable skipCheck4;
    bool public immutable skipCheck5;
    bool public immutable skipCheck6;
    bool public immutable skipCheck7;

    uint256 public immutable weight0;
    uint256 public immutable weight1;
    uint256 public immutable weight2;
    uint256 public immutable weight3;
    uint256 public immutable weight4;
    uint256 public immutable weight5;
    uint256 public immutable weight6;
    uint256 public immutable weight7;

    uint256 immutable index0;
    uint256 immutable index1;
    uint256 immutable index2;
    uint256 immutable index3;
    uint256 immutable index4;
    uint256 immutable index5;
    uint256 immutable index6;
    uint256 immutable index7;

    uint256 immutable scale0;
    uint256 immutable scale1;
    uint256 immutable scale2;
    uint256 immutable scale3;
    uint256 immutable scale4;
    uint256 immutable scale5;
    uint256 immutable scale6;
    uint256 immutable scale7;

    constructor(
        address _acl,
        address _priceOracle,
        uint256 lowerBound,
        address _vault,
        address _pool,
        PriceFeedParams[] memory priceFeeds
    )
        LPPriceFeed(_acl, _priceOracle, _pool, _pool) // U:[BAL-W-1]
        nonZeroAddress(_vault) // U:[BAL-W-1]
        nonZeroAddress(priceFeeds[0].priceFeed) // U:[BAL-W-2]
        nonZeroAddress(priceFeeds[1].priceFeed) // U:[BAL-W-2]
    {
        uint256[] memory weights = IBalancerWeightedPool(_pool).getNormalizedWeights();
        uint256[] memory indices = _sort(weights);

        numAssets = weights.length; // U:[BAL-W-2]
        vault = _vault; // U:[BAL-W-1]
        poolId = IBalancerWeightedPool(_pool).getPoolId(); // U:[BAL-W-1]

        index0 = indices[0];
        index1 = indices[1];
        index2 = numAssets >= 3 ? indices[2] : 0;
        index3 = numAssets >= 4 ? indices[3] : 0;
        index4 = numAssets >= 5 ? indices[4] : 0;
        index5 = numAssets >= 6 ? indices[5] : 0;
        index6 = numAssets >= 7 ? indices[6] : 0;
        index7 = numAssets >= 8 ? indices[7] : 0;

        weight0 = weights[0];
        weight1 = weights[1];
        weight2 = numAssets >= 3 ? weights[2] : 0;
        weight3 = numAssets >= 4 ? weights[3] : 0;
        weight4 = numAssets >= 5 ? weights[4] : 0;
        weight5 = numAssets >= 6 ? weights[5] : 0;
        weight6 = numAssets >= 7 ? weights[6] : 0;
        weight7 = numAssets >= 8 ? weights[7] : 0;

        (address[] memory tokens,,) = IBalancerVault(_vault).getPoolTokens(poolId);
        scale0 = _tokenScale(tokens[index0]);
        scale1 = _tokenScale(tokens[index1]);
        scale2 = numAssets >= 3 ? _tokenScale(tokens[index2]) : 0;
        scale3 = numAssets >= 4 ? _tokenScale(tokens[index3]) : 0;
        scale4 = numAssets >= 5 ? _tokenScale(tokens[index4]) : 0;
        scale5 = numAssets >= 6 ? _tokenScale(tokens[index5]) : 0;
        scale6 = numAssets >= 7 ? _tokenScale(tokens[index6]) : 0;
        scale7 = numAssets >= 8 ? _tokenScale(tokens[index7]) : 0;

        priceFeed0 = priceFeeds[index0].priceFeed;
        priceFeed1 = priceFeeds[index1].priceFeed;
        priceFeed2 = numAssets >= 3 ? priceFeeds[index2].priceFeed : address(0);
        priceFeed3 = numAssets >= 4 ? priceFeeds[index3].priceFeed : address(0);
        priceFeed4 = numAssets >= 5 ? priceFeeds[index4].priceFeed : address(0);
        priceFeed5 = numAssets >= 6 ? priceFeeds[index5].priceFeed : address(0);
        priceFeed6 = numAssets >= 7 ? priceFeeds[index6].priceFeed : address(0);
        priceFeed7 = numAssets >= 8 ? priceFeeds[index7].priceFeed : address(0);

        stalenessPeriod0 = priceFeeds[index0].stalenessPeriod;
        stalenessPeriod1 = priceFeeds[index1].stalenessPeriod;
        stalenessPeriod2 = numAssets >= 3 ? priceFeeds[index2].stalenessPeriod : 0;
        stalenessPeriod3 = numAssets >= 4 ? priceFeeds[index3].stalenessPeriod : 0;
        stalenessPeriod4 = numAssets >= 5 ? priceFeeds[index4].stalenessPeriod : 0;
        stalenessPeriod5 = numAssets >= 6 ? priceFeeds[index5].stalenessPeriod : 0;
        stalenessPeriod6 = numAssets >= 7 ? priceFeeds[index6].stalenessPeriod : 0;
        stalenessPeriod7 = numAssets >= 8 ? priceFeeds[index7].stalenessPeriod : 0;

        skipCheck0 = _validatePriceFeed(priceFeed0, stalenessPeriod0);
        skipCheck1 = _validatePriceFeed(priceFeed1, stalenessPeriod1);
        skipCheck2 = numAssets >= 3 ? _validatePriceFeed(priceFeed2, stalenessPeriod2) : false;
        skipCheck3 = numAssets >= 4 ? _validatePriceFeed(priceFeed3, stalenessPeriod3) : false;
        skipCheck4 = numAssets >= 5 ? _validatePriceFeed(priceFeed4, stalenessPeriod4) : false;
        skipCheck5 = numAssets >= 6 ? _validatePriceFeed(priceFeed5, stalenessPeriod5) : false;
        skipCheck6 = numAssets >= 7 ? _validatePriceFeed(priceFeed6, stalenessPeriod6) : false;
        skipCheck7 = numAssets >= 8 ? _validatePriceFeed(priceFeed7, stalenessPeriod7) : false;

        _setLimiter(lowerBound); // U:[BAL-W-1]
    }

    // ------- //
    // PRICING //
    // ------- //

    function getAggregatePrice() public view override returns (int256 answer) {
        uint256[] memory weights = _getWeightsArray();

        uint256 weightedPrice = FixedPoint.ONE;
        uint256 currentBase = FixedPoint.ONE;
        for (uint256 i = 0; i < numAssets;) {
            (address priceFeed, uint32 stalenessPeriod, bool skipCheck) = _getPriceFeedParams(i);
            answer = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck);
            answer = answer * int256(WAD_OVER_USD_FEED_SCALE);

            currentBase = currentBase.mulDown(uint256(answer).divDown(weights[i]));
            if (i == numAssets - 1 || weights[i] != weights[i + 1]) {
                weightedPrice = weightedPrice.mulDown(currentBase.powDown(weights[i]));
                currentBase = FixedPoint.ONE;
            }

            unchecked {
                ++i;
            }
        }

        answer = int256(weightedPrice / (numAssets * WAD_OVER_USD_FEED_SCALE)); // U:[BAL-W-2]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return (numAssets * _getBPTInvariant()).divDown(_getBPTSupply()); // U:[BAL-W-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[BAL-W-1]
    }

    /// @dev Returns BPT invariant
    function _getBPTInvariant() internal view returns (uint256 k) {
        uint256[] memory balances = _getBalancesArray();
        uint256[] memory weights = _getWeightsArray();

        uint256 len = balances.length;

        k = FixedPoint.ONE;
        uint256 currentBase = FixedPoint.ONE;
        for (uint256 i = 0; i < len;) {
            currentBase = currentBase.mulDown(balances[i]);
            if (i == len - 1 || weights[i] != weights[i + 1]) {
                k = k.mulDown(currentBase.powDown(weights[i]));
                currentBase = FixedPoint.ONE;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns BPT total supply
    function _getBPTSupply() internal view returns (uint256 supply) {
        try IBalancerWeightedPool(lpToken).getActualSupply() returns (uint256 actualSupply) {
            supply = actualSupply;
        } catch {
            supply = IBalancerWeightedPool(lpToken).totalSupply();
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns i-th price feed params
    function _getPriceFeedParams(uint256 i)
        internal
        view
        returns (address priceFeed, uint32 stalenessPeriod, bool skipCheck)
    {
        if (i == 0) return (priceFeed0, stalenessPeriod0, skipCheck0);
        if (i == 1) return (priceFeed1, stalenessPeriod1, skipCheck1);
        if (i == 2) return (priceFeed2, stalenessPeriod2, skipCheck2);
        if (i == 3) return (priceFeed3, stalenessPeriod3, skipCheck3);
        if (i == 4) return (priceFeed4, stalenessPeriod4, skipCheck4);
        if (i == 5) return (priceFeed5, stalenessPeriod5, skipCheck5);
        if (i == 6) return (priceFeed6, stalenessPeriod6, skipCheck6);
        if (i == 7) return (priceFeed7, stalenessPeriod7, skipCheck7);
    }

    /// @dev Returns weights as an array
    function _getWeightsArray() internal view returns (uint256[] memory weights) {
        weights = new uint256[](numAssets);
        weights[0] = weight0;
        weights[1] = weight1;
        if (numAssets >= 3) weights[2] = weight2;
        if (numAssets >= 4) weights[3] = weight3;
        if (numAssets >= 5) weights[4] = weight4;
        if (numAssets >= 6) weights[5] = weight5;
        if (numAssets >= 7) weights[6] = weight6;
        if (numAssets >= 8) weights[7] = weight7;
    }

    /// @dev Returns assets balances sorted in the order of increasing weights and scaled to have the same precision
    function _getBalancesArray() internal view returns (uint256[] memory balances) {
        (, uint256[] memory rawBalances,) = IBalancerVault(vault).getPoolTokens(poolId);

        balances = new uint256[](numAssets);
        balances[0] = rawBalances[index0] * WAD / scale0;
        balances[1] = rawBalances[index1] * WAD / scale1;
        if (numAssets >= 3) balances[2] = rawBalances[index2] * WAD / scale2;
        if (numAssets >= 4) balances[3] = rawBalances[index3] * WAD / scale3;
        if (numAssets >= 5) balances[4] = rawBalances[index4] * WAD / scale4;
        if (numAssets >= 6) balances[5] = rawBalances[index5] * WAD / scale5;
        if (numAssets >= 7) balances[6] = rawBalances[index6] * WAD / scale6;
        if (numAssets >= 8) balances[7] = rawBalances[index7] * WAD / scale7;
    }

    /// @dev Returns `token`'s scale (10^decimals)
    function _tokenScale(address token) internal view returns (uint256) {
        return 10 ** IERC20Metadata(token).decimals();
    }

    // ------- //
    // SORTING //
    // ------- //

    /// @dev Sorts array in-place in ascending order, also returns the resulting permutation
    function _sort(uint256[] memory data) internal pure returns (uint256[] memory indices) {
        uint256 len = data.length;
        indices = new uint256[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                indices[i] = i;
            }
        }
        _quickSort(data, indices, 0, len - 1);
    }

    /// @dev Quick sort sub-routine
    function _quickSort(uint256[] memory data, uint256[] memory indices, uint256 low, uint256 high) private pure {
        unchecked {
            if (low < high) {
                uint256 pVal = data[(low + high) / 2];

                uint256 i = low;
                uint256 j = high;
                for (;;) {
                    while (data[i] < pVal) i++;
                    while (data[j] > pVal) j--;
                    if (i >= j) break;
                    if (data[i] != data[j]) {
                        (data[i], data[j]) = (data[j], data[i]);
                        (indices[i], indices[j]) = (indices[j], indices[i]);
                    }
                    i++;
                    j--;
                }
                if (low < j) _quickSort(data, indices, low, j);
                j++;
                if (j < high) _quickSort(data, indices, j, high);
            }
        }
    }
}
