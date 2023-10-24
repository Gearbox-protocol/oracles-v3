// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {BalancerVaultMock, PoolToken} from "../../mocks/balancer/BalancerVaultMock.sol";
import {BalancerWeightedPoolMock} from "../../mocks/balancer/BalancerWeightedPoolMock.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {IBalancerVault} from "../../../interfaces/balancer/IBalancerVault.sol";
import {IBalancerWeightedPool} from "../../../interfaces/balancer/IBalancerWeightedPool.sol";
import {PriceFeedParams} from "../../../oracles/PriceFeedParams.sol";
import {BPTWeightedPriceFeedHarness} from "./BPTWeightedPriceFeed.harness.sol";

import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

contract BPTWeightedPriceFeedUnitTest is PriceFeedUnitTestHelper {
    BPTWeightedPriceFeedHarness priceFeed;
    BalancerVaultMock balancerVault;
    BalancerWeightedPoolMock balancerPool;

    ERC20Mock[8] underlyings;
    PriceFeedMock[8] underlyingPriceFeeds;

    function setUp() public {
        _setUp();
        for (uint256 i; i < 8; ++i) {
            underlyings[i] = new ERC20Mock(
                string.concat("Test Token ", vm.toString(i)),
                string.concat("TEST", vm.toString(i)),
                uint8(18 - i)
            );
            underlyingPriceFeeds[i] = new PriceFeedMock(int256(1e8 * 4 ** i), 8);
        }
    }

    /// @notice U:[BAL-W-1]: LP-related functionality works as expected
    function test_U_BAL_W_01_lp_related_functiontionality_works_as_expected() public {
        _setupBalancerMocks(8);

        vm.expectRevert(ZeroAddressException.selector);
        new BPTWeightedPriceFeedHarness(
            address(addressProvider),
            address(0),
            address(balancerPool),
            _getUnderlyingPriceFeeds(8)
        );

        vm.expectRevert(ZeroAddressException.selector);
        new BPTWeightedPriceFeedHarness(
            address(addressProvider),
            address(balancerVault),
            address(0),
            _getUnderlyingPriceFeeds(8)
        );

        priceFeed = _newBalancerPriceFeed(8);

        assertEq(priceFeed.poolId(), "TEST_POOL", "Incorrect poolId");
        assertEq(priceFeed.vault(), address(balancerVault), "Incorrect vault");
        assertEq(priceFeed.lpToken(), address(balancerPool), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(balancerPool), "Incorrect lpToken");
        assertApproxEqAbs(priceFeed.lowerBound(), 1.0098 ether, 1e6, "Incorrect lower bound"); // 1.02 * 0.99

        balancerVault.hackPoolTokens("TEST_POOL", _getPoolTokens(8, 1.03 ether));
        assertApproxEqAbs(priceFeed.getLPExchangeRate(), 1.03 ether, 1e6, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }

    /// @notice U:[BAL-W-2]: Underlying price feeds-related functionality works as expected
    function test_U_BAL_W_02_underlying_price_feeds_related_functiontionality_works_as_expected() public {
        for (uint256 numAssets = 2; numAssets <= 8; ++numAssets) {
            _setupBalancerMocks(numAssets);

            if (numAssets < 2) {
                vm.expectRevert(ZeroAddressException.selector);
                _newBalancerPriceFeed(numAssets);
                continue;
            }

            priceFeed = _newBalancerPriceFeed(numAssets);
            assertEq(priceFeed.numAssets(), numAssets, "Incorrect numAssets");

            int256 answer = priceFeed.getAggregatePrice();
            assertApproxEqAbs(answer, int256(numAssets * 1e8 * 2 ** (numAssets - 1)), 1, "Incorrect answer");
        }
    }

    /// @notice U:[BAL-W-3]: Formulas compute correctly with different weights
    function test_U_BAL_W_03_formulas_compute_correctly_with_different_weights() public {
        // weights are 0.2, 0.3, and 0.5
        uint256[] memory weights = new uint256[](3);
        weights[0] = 0.2 ether;
        weights[1] = 0.3 ether;
        weights[2] = 0.5 ether;

        // total supply of the pool is 1
        balancerPool = new BalancerWeightedPoolMock("TEST_POOL", 1 ether, false, weights);

        // token balances are 1, 0.5 and 0.25
        PoolToken[] memory poolTokens = new PoolToken[](3);
        poolTokens[0] = PoolToken(address(underlyings[0]), 1 ether);
        poolTokens[1] = PoolToken(address(underlyings[1]), 0.5 ether / 10);
        poolTokens[2] = PoolToken(address(underlyings[2]), 0.25 ether / 100);

        balancerVault = new BalancerVaultMock();
        balancerVault.hackPoolTokens("TEST_POOL", poolTokens);

        // underlying token prices are $1, $4, and $16
        priceFeed = _newBalancerPriceFeed(3);

        assertApproxEqAbs(
            priceFeed.getAggregatePrice(),
            1697659589, // `(1 / 0.2) ** 0.2 * (4 / 0.3) ** 0.3 * (16 / 0.5) ** 0.5` with 8 decimals
            1,
            "Incorrect aggregate price"
        );

        assertApproxEqAbs(
            priceFeed.getLPExchangeRate(),
            406126198178117824, // `1 ** 0.2 * 0.5 ** 0.3 * 0.25 ** 0.5` with 18 decimals
            1e6,
            "Incorrect LP exchange rate"
        );
    }

    /// @notice U:[BAL-W-4]: Sorting works as expected
    function test_U_BAL_W_04_sorting_works_as_expected() public {
        // weights are 0.5, 0.3, and 0.2
        uint256[] memory weights = new uint256[](3);
        weights[0] = 0.5 ether;
        weights[1] = 0.3 ether;
        weights[2] = 0.2 ether;

        // total supply of the pool is 1
        balancerPool = new BalancerWeightedPoolMock("TEST_POOL", 1 ether, false, weights);

        // token balances are 1, 0.5 and 0.25
        PoolToken[] memory poolTokens = new PoolToken[](3);
        poolTokens[0] = PoolToken(address(underlyings[0]), 1 ether);
        poolTokens[1] = PoolToken(address(underlyings[1]), 0.5 ether / 10);
        poolTokens[2] = PoolToken(address(underlyings[2]), 0.25 ether / 100);

        balancerVault = new BalancerVaultMock();
        balancerVault.hackPoolTokens("TEST_POOL", poolTokens);

        priceFeed = _newBalancerPriceFeed(3);

        uint256[] memory expectedWeights = new uint256[](3);
        expectedWeights[0] = 0.2 ether;
        expectedWeights[1] = 0.3 ether;
        expectedWeights[2] = 0.5 ether;
        assertEq(priceFeed.getWeightsArrayExposed(), expectedWeights, "Incorrect weights");

        uint256[] memory expectedBalances = new uint256[](3);
        expectedBalances[0] = 0.25 ether;
        expectedBalances[1] = 0.5 ether;
        expectedBalances[2] = 1 ether;
        assertEq(priceFeed.getBalancesArrayExposed(), expectedBalances, "Incorrect balances");

        assertEq(priceFeed.priceFeed0(), address(underlyingPriceFeeds[2]), "Incorrect priceFeed0");
        assertEq(priceFeed.priceFeed1(), address(underlyingPriceFeeds[1]), "Incorrect priceFeed1");
        assertEq(priceFeed.priceFeed2(), address(underlyingPriceFeeds[0]), "Incorrect priceFeed2");

        assertEq(priceFeed.stalenessPeriod0(), 3 hours, "Incorrect stalenessPeriod0");
        assertEq(priceFeed.stalenessPeriod1(), 2 hours, "Incorrect stalenessPeriod1");
        assertEq(priceFeed.stalenessPeriod2(), 1 hours, "Incorrect stalenessPeriod2");
    }

    // ------- //
    // HELPERS //
    // ------- //

    function _setupBalancerMocks(uint256 numAssets) internal {
        balancerVault = new BalancerVaultMock();
        balancerPool = new BalancerWeightedPoolMock("TEST_POOL", 1 ether, false, _getNormalizedWeights(numAssets));
        balancerVault.hackPoolTokens("TEST_POOL", _getPoolTokens(numAssets, 1.02 ether));
    }

    function _newBalancerPriceFeed(uint256 numFeeds) internal returns (BPTWeightedPriceFeedHarness) {
        return new BPTWeightedPriceFeedHarness(
            address(addressProvider),
            address(balancerVault),
            address(balancerPool),
            _getUnderlyingPriceFeeds(numFeeds)
        );
    }

    function _getPoolTokens(uint256 numAssets, uint256 scaledBalance)
        internal
        view
        returns (PoolToken[] memory poolTokens)
    {
        poolTokens = new PoolToken[](numAssets);
        for (uint256 i; i < numAssets; ++i) {
            poolTokens[i] = PoolToken(address(underlyings[i]), scaledBalance / 10 ** i);
        }
    }

    function _getNormalizedWeights(uint256 numAssets) internal pure returns (uint256[] memory weights) {
        weights = new uint256[](numAssets);
        for (uint256 i; i < numAssets; ++i) {
            weights[i] = 1 ether / numAssets;
        }
    }

    function _getUnderlyingPriceFeeds(uint256 numFeeds) internal view returns (PriceFeedParams[] memory priceFeeds) {
        priceFeeds = new PriceFeedParams[](numFeeds < 3 ? 2 : numFeeds);
        for (uint256 i; i < numFeeds; ++i) {
            priceFeeds[i] = PriceFeedParams(address(underlyingPriceFeeds[i]), uint32(i + 1) * 1 hours);
        }
    }
}
