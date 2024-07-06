// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {
    IncorrectPriceFeedException,
    StalePriceException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {PriceFeedParams} from "../../oracles/PriceFeedParams.sol";
import {CompositePriceFeed} from "../../oracles/CompositePriceFeed.sol";

/// @title Composite price feed unit test
/// @notice U:[CPF]: Unit tests for composite price feed
contract CompositePriceFeedUnitTest is Test {
    CompositePriceFeed priceFeed;

    PriceFeedMock targetPriceFeed;
    PriceFeedMock basePriceFeed;

    function setUp() public {
        targetPriceFeed = new PriceFeedMock(2 ether, 18);
        basePriceFeed = new PriceFeedMock(0.5e8, 8);

        vm.mockCall(address(targetPriceFeed), abi.encodeCall(PriceFeedMock.description, ()), abi.encode("TEST / ETH"));
        vm.mockCall(address(basePriceFeed), abi.encodeCall(PriceFeedMock.description, ()), abi.encode("ETH / USD"));

        priceFeed = new CompositePriceFeed(
            [PriceFeedParams(address(targetPriceFeed), 1 days), PriceFeedParams(address(basePriceFeed), 1 days)]
        );
    }

    /// @notice U:[CPF-1]: Constructor works as expected
    function test_U_CPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new CompositePriceFeed([PriceFeedParams(address(0), 1 days), PriceFeedParams(address(basePriceFeed), 1 days)]);

        vm.expectRevert(ZeroAddressException.selector);
        new CompositePriceFeed([PriceFeedParams(address(targetPriceFeed), 1 days), PriceFeedParams(address(0), 1 days)]);

        PriceFeedMock invalidPriceFeed = new PriceFeedMock(1 ether, 18);
        vm.expectRevert(IncorrectPriceFeedException.selector);
        new CompositePriceFeed(
            [PriceFeedParams(address(targetPriceFeed), 1 days), PriceFeedParams(address(invalidPriceFeed), 1 days)]
        );

        assertEq(priceFeed.targetFeedScale(), 1e18, "Incorrect targetFeedScale");

        assertEq(priceFeed.priceFeed0(), address(targetPriceFeed), "Incorrect priceFeed0");
        assertEq(priceFeed.priceFeed1(), address(basePriceFeed), "Incorrect priceFeed1");

        assertEq(priceFeed.stalenessPeriod0(), 1 days, "Incorrect stalenessPeriod0");
        assertEq(priceFeed.stalenessPeriod1(), 1 days, "Incorrect stalenessPeriod1");

        assertFalse(priceFeed.skipCheck1(), "Incorrect skipCheck1");
    }

    /// @notice U:[CPF-2]: Price feed has correct metadata
    function test_U_CPF_02_price_feed_has_correct_metadata() public {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "TEST / ETH * ETH / USD composite price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
    }

    /// @notice U:[CPF-3]: `latestRoundData` works as expected
    function test_U_CPF_03_latestRoundData_works_as_expected() public {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 1e8, "Incorrect answer");

        // reverts on stale target price feed answer
        targetPriceFeed.setParams(0, 0, block.timestamp - 2 days, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.latestRoundData();

        // reverts on stale base price feed answer
        targetPriceFeed.setParams(0, 0, block.timestamp, 0);
        basePriceFeed.setParams(0, 0, block.timestamp - 2 days, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.latestRoundData();
    }
}
