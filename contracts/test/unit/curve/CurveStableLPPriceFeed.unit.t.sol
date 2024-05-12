// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {CurvePoolMock} from "../../mocks/curve/CurvePoolMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";
import {PriceFeedParams} from "../../../oracles/PriceFeedParams.sol";
import {CurveStableLPPriceFeed} from "../../../oracles/curve/CurveStableLPPriceFeed.sol";

import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

contract CurveStableLPPriceFeedUnitTest is PriceFeedUnitTestHelper {
    CurveStableLPPriceFeed priceFeed;
    CurvePoolMock curvePool;

    address lpToken;
    PriceFeedMock[4] underlyingPriceFeeds;

    function setUp() public {
        _setUp();

        lpToken = makeAddr("LP_TOKEN");

        curvePool = new CurvePoolMock();
        curvePool.hack_virtual_price(1.03 ether);

        for (uint256 i; i < 4; ++i) {
            underlyingPriceFeeds[i] = new PriceFeedMock(int256(1e6 * (100 - i)), 8);
        }
    }

    /// @notice U:[CRV-S-1]: LP-related functionality works as expected
    function test_U_CRV_S_01_lp_related_functiontionality_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new CurveStableLPPriceFeed(
            address(addressProvider),
            priceOracle,
            1.02 ether,
            address(0),
            address(curvePool),
            _getUnderlyingPriceFeeds(4)
        );

        vm.expectRevert(ZeroAddressException.selector);
        new CurveStableLPPriceFeed(
            address(addressProvider), priceOracle, 1.02 ether, lpToken, address(0), _getUnderlyingPriceFeeds(4)
        );

        priceFeed = _newCurvePriceFeed(4, 1.02 ether);

        assertEq(priceFeed.lpToken(), lpToken, "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(curvePool), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.02 ether, "Incorrect lower bound");

        curvePool.hack_virtual_price(1.03 ether);
        vm.expectCall(address(curvePool), abi.encodeCall(ICurvePool.get_virtual_price, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.03 ether, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }

    /// @notice U:[CRV-S-2]: Underlying price feeds-related functionality works as expected
    function test_U_CRV_S_02_underlying_price_feeds_related_functiontionality_works_as_expected() public {
        for (uint256 numFeeds; numFeeds <= 4; ++numFeeds) {
            if (numFeeds < 2) {
                vm.expectRevert(ZeroAddressException.selector);
                _newCurvePriceFeed(numFeeds, 1.02 ether);
                continue;
            }

            priceFeed = _newCurvePriceFeed(numFeeds, 1.02 ether);
            assertEq(priceFeed.nCoins(), numFeeds, "Incorrect nCoins");

            int256 answer = priceFeed.getAggregatePrice();
            assertEq(answer, int256(1e6 * (101 - numFeeds)), "Incorrect answer");
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    function _newCurvePriceFeed(uint256 numFeeds, uint256 lowerBound) internal returns (CurveStableLPPriceFeed) {
        return new CurveStableLPPriceFeed(
            address(addressProvider),
            priceOracle,
            lowerBound,
            lpToken,
            address(curvePool),
            _getUnderlyingPriceFeeds(numFeeds)
        );
    }

    function _getUnderlyingPriceFeeds(uint256 numFeeds) internal view returns (PriceFeedParams[4] memory priceFeeds) {
        if (numFeeds >= 1) priceFeeds[0] = PriceFeedParams(address(underlyingPriceFeeds[0]), 1 days);
        if (numFeeds >= 2) priceFeeds[1] = PriceFeedParams(address(underlyingPriceFeeds[1]), 1 days);
        if (numFeeds >= 3) priceFeeds[2] = PriceFeedParams(address(underlyingPriceFeeds[2]), 1 days);
        if (numFeeds >= 4) priceFeeds[3] = PriceFeedParams(address(underlyingPriceFeeds[3]), 1 days);
    }
}
