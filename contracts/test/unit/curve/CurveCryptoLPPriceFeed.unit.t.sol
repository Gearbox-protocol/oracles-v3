// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedTest} from "../PriceFeedTest.sol";

import {CurvePoolMock} from "../../mocks/curve/CurvePoolMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";
import {PriceFeedParams} from "../../../oracles/PriceFeedParams.sol";
import {CurveCryptoLPPriceFeed} from "../../../oracles/curve/CurveCryptoLPPriceFeed.sol";

import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

contract CurveCryptoLPPriceFeedUnitTest is PriceFeedTest {
    CurveCryptoLPPriceFeed priceFeed;
    CurvePoolMock curvePool;

    address lpToken;
    PriceFeedMock[3] underlyingPriceFeeds;

    function setUp() public {
        _setUp();

        lpToken = makeAddr("LP_TOKEN");

        curvePool = new CurvePoolMock();
        curvePool.hack_virtual_price(1.02 ether);

        for (uint256 i; i < 3; ++i) {
            underlyingPriceFeeds[i] = new PriceFeedMock(int256(1e8 * 4 ** i), 8);
        }
    }

    /// @notice U:[CRV-C-1]: LP-related functionality works as expected
    function test_U_CRV_C_01_lp_related_functiontionality_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new CurveCryptoLPPriceFeed(
            address(addressProvider),
            address(0),
            address(curvePool),
            _getUnderlyingPriceFeeds(3)
        );

        vm.expectRevert(ZeroAddressException.selector);
        new CurveCryptoLPPriceFeed(
            address(addressProvider),
            lpToken,
            address(0),
            _getUnderlyingPriceFeeds(3)
        );

        priceFeed = _newCurvePriceFeed(3);

        assertEq(priceFeed.lpToken(), lpToken, "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(curvePool), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.01796 ether, "Incorrect lower bound"); // 1.02 * 0.998

        curvePool.hack_virtual_price(1.03 ether);
        vm.expectCall(address(curvePool), abi.encodeCall(ICurvePool.get_virtual_price, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.03 ether, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }

    /// @notice U:[CRV-C-2]: Underlying price feeds-related functionality works as expected
    function test_U_CRV_C_02_underlying_price_feeds_related_functiontionality_works_as_expected() public {
        for (uint256 numFeeds; numFeeds <= 3; ++numFeeds) {
            if (numFeeds < 2) {
                vm.expectRevert(ZeroAddressException.selector);
                _newCurvePriceFeed(numFeeds);
                continue;
            }

            priceFeed = _newCurvePriceFeed(numFeeds);
            assertEq(priceFeed.nCoins(), numFeeds, "Incorrect nCoins");

            int256 answer = priceFeed.getAggregatePrice();
            assertApproxEqAbs(answer, int256(int256(numFeeds * 1e8 * 2 ** (numFeeds - 1))), 1, "Incorrect answer");
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    function _newCurvePriceFeed(uint256 numFeeds) internal returns (CurveCryptoLPPriceFeed) {
        return new CurveCryptoLPPriceFeed(
            address(addressProvider),
            lpToken,
            address(curvePool),
            _getUnderlyingPriceFeeds(numFeeds)
        );
    }

    function _getUnderlyingPriceFeeds(uint256 numFeeds) internal view returns (PriceFeedParams[3] memory priceFeeds) {
        if (numFeeds >= 1) priceFeeds[0] = PriceFeedParams(address(underlyingPriceFeeds[0]), 1 days);
        if (numFeeds >= 2) priceFeeds[1] = PriceFeedParams(address(underlyingPriceFeeds[1]), 1 days);
        if (numFeeds >= 3) priceFeeds[2] = PriceFeedParams(address(underlyingPriceFeeds[2]), 1 days);
    }
}
