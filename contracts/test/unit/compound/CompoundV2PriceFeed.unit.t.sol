// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {CTokenMock} from "../../mocks/compound/CTokenMock.sol";

import {ICToken} from "../../../interfaces/compound/ICToken.sol";
import {CompoundV2PriceFeed} from "../../../oracles/compound/CompoundV2PriceFeed.sol";

contract CompoundV2PriceFeedUnitTest is PriceFeedUnitTestHelper {
    CompoundV2PriceFeed priceFeed;
    CTokenMock cToken;

    function setUp() public {
        _setUp();

        cToken = new CTokenMock();
        cToken.hackExchangeRateStored(1.02 ether);

        priceFeed = new CompoundV2PriceFeed(
            address(addressProvider),
            address(cToken),
            address(underlyingPriceFeed),
            1 days
        );

        cToken.hackExchangeRateStored(1.03 ether);
    }

    /// @notice U:[COMP-1]: Price feed works as expected
    function test_U_COMP_01_price_feed_works_as_expected() public {
        // constructor
        assertEq(priceFeed.lpToken(), address(cToken), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(cToken), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.0098 ether, "Incorrect lower bound"); // 1.02 * 0.99

        // overriden functions
        vm.expectCall(address(cToken), abi.encodeCall(ICToken.exchangeRateStored, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.03 ether, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1 ether, "Incorrect getScale");
    }
}
