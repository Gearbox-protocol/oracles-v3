// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {CurvePoolMock} from "../../mocks/curve/CurvePoolMock.sol";

import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";
import {CurveUSDPriceFeed} from "../../../oracles/curve/CurveUSDPriceFeed.sol";

contract CurveUSDPriceFeedUnitTest is PriceFeedUnitTestHelper {
    CurveUSDPriceFeed priceFeed;
    CurvePoolMock curvePool;
    address crvUSD;

    function setUp() public {
        _setUp();

        crvUSD = makeAddr("crvUSD");
        curvePool = new CurvePoolMock();
        curvePool.hack_price_oracle(1.02 ether);

        priceFeed = new CurveUSDPriceFeed(
            address(addressProvider),
            crvUSD,
            address(curvePool),
            address(underlyingPriceFeed),
            1 days
        );
    }

    /// @notice U:[CRV-D-1]: Price feed works as expected
    function test_U_CRV_D_01_price_feed_works_as_expected() public {
        // constructor
        assertEq(priceFeed.lpToken(), crvUSD, "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(curvePool), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.01796 ether, "Incorrect lower bound"); // 1.02 * 0.998

        // overriden functions
        curvePool.hack_price_oracle(1.03 ether);
        vm.expectCall(address(curvePool), abi.encodeCall(ICurvePool.price_oracle, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.03 ether, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }
}
