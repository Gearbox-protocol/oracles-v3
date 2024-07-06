// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {BalancerStablePoolMock} from "../../mocks/balancer/BalancerStablePoolMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {IBalancerStablePool} from "../../../interfaces/balancer/IBalancerStablePool.sol";
import {PriceFeedParams} from "../../../oracles/PriceFeedParams.sol";
import {BPTStablePriceFeed} from "../../../oracles/balancer/BPTStablePriceFeed.sol";

import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

contract BPTStablePriceFeedUnitTest is PriceFeedUnitTestHelper {
    BPTStablePriceFeed priceFeed;
    BalancerStablePoolMock balancerPool;

    PriceFeedMock[5] underlyingPriceFeeds;

    function setUp() public {
        _setUp();

        balancerPool = new BalancerStablePoolMock();
        balancerPool.hackRate(1.03 ether);

        for (uint256 i; i < 5; ++i) {
            underlyingPriceFeeds[i] = new PriceFeedMock(int256(1e6 * (100 - i)), 8);
        }
    }

    /// @notice U:[BAL-S-1]: LP-related functionality works as expected
    function test_U_BAL_S_01_lp_related_functiontionality_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new BPTStablePriceFeed(
            address(addressProvider), priceOracle, 1.02 ether, address(0), _getUnderlyingPriceFeeds(5)
        );

        priceFeed = _newBalancerPriceFeed(5, 1.02 ether);

        assertEq(priceFeed.lpToken(), address(balancerPool), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(balancerPool), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.02 ether, "Incorrect lower bound");

        vm.expectCall(address(balancerPool), abi.encodeCall(IBalancerStablePool.getRate, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.03 ether, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }

    /// @notice U:[BAL-S-2]: Underlying price feeds-related functionality works as expected
    function test_U_BAL_S_02_underlying_price_feeds_related_functiontionality_works_as_expected() public {
        for (uint256 numFeeds; numFeeds <= 5; ++numFeeds) {
            if (numFeeds < 2) {
                vm.expectRevert(ZeroAddressException.selector);
                _newBalancerPriceFeed(numFeeds, 1.02 ether);
                continue;
            }

            priceFeed = _newBalancerPriceFeed(numFeeds, 1.02 ether);
            assertEq(priceFeed.numAssets(), numFeeds, "Incorrect numAssets");

            int256 answer = priceFeed.getAggregatePrice();
            assertEq(answer, int256(1e6 * (101 - numFeeds)), "Incorrect answer");
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    function _newBalancerPriceFeed(uint256 numFeeds, uint256 lowerBound) internal returns (BPTStablePriceFeed) {
        return new BPTStablePriceFeed(
            address(addressProvider), priceOracle, lowerBound, address(balancerPool), _getUnderlyingPriceFeeds(numFeeds)
        );
    }

    function _getUnderlyingPriceFeeds(uint256 numFeeds) internal view returns (PriceFeedParams[5] memory priceFeeds) {
        if (numFeeds >= 1) priceFeeds[0] = PriceFeedParams(address(underlyingPriceFeeds[0]), 1 days);
        if (numFeeds >= 2) priceFeeds[1] = PriceFeedParams(address(underlyingPriceFeeds[1]), 1 days);
        if (numFeeds >= 3) priceFeeds[2] = PriceFeedParams(address(underlyingPriceFeeds[2]), 1 days);
        if (numFeeds >= 4) priceFeeds[3] = PriceFeedParams(address(underlyingPriceFeeds[3]), 1 days);
        if (numFeeds >= 5) priceFeeds[4] = PriceFeedParams(address(underlyingPriceFeeds[4]), 1 days);
    }
}
