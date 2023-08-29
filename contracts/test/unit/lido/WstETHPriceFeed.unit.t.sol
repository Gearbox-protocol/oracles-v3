// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedTest} from "../PriceFeedTest.sol";

import {WstETHMock} from "../../mocks/integrations/lido/WstETHMock.sol";

import {IwstETHGetters} from "../../../interfaces/lido/IwstETH.sol";
import {WstETHPriceFeed} from "../../../oracles/lido/WstETHPriceFeed.sol";

contract WstETHPriceFeedUnitTest is PriceFeedTest {
    WstETHPriceFeed priceFeed;
    WstETHMock wstETH;

    function setUp() public {
        _setUp();

        wstETH = new WstETHMock();
        wstETH.hackStEthPerToken(1.02 ether);

        priceFeed = new WstETHPriceFeed(
            address(addressProvider),
            address(wstETH),
            address(underlyingPriceFeed),
            1 days
        );

        wstETH.hackStEthPerToken(1.03 ether);
    }

    /// @notice U:[LDO-1]: Price feed works as expected
    function test_U_LDO_01_price_feed_works_as_expected() public {
        // constructor
        assertEq(priceFeed.lpToken(), address(wstETH), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(wstETH), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.01796 ether, "Incorrect lower bound"); // 1.02 * 0.998

        // overriden functions
        vm.expectCall(address(wstETH), abi.encodeCall(IwstETHGetters.stEthPerToken, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.03 ether, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }
}
