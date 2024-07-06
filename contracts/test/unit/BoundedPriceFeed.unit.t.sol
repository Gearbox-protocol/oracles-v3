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

import {BoundedPriceFeed} from "../../oracles/BoundedPriceFeed.sol";

/// @title Bounded price feed unit test
/// @notice U:[BPF]: Unit tests for bounded price feed
contract BoundedPriceFeedUnitTest is Test {
    BoundedPriceFeed priceFeed;

    PriceFeedMock underlyingPriceFeed;

    function setUp() public {
        underlyingPriceFeed = new PriceFeedMock(1e8, 8);
        vm.mockCall(
            address(underlyingPriceFeed), abi.encodeCall(PriceFeedMock.description, ()), abi.encode("TEST / USD")
        );

        priceFeed = new BoundedPriceFeed(address(underlyingPriceFeed), 1 days, 1.1e8);
    }

    /// @notice U:[BPF-1]: Constructor works as expected
    function test_U_BPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new BoundedPriceFeed(address(0), 1 days, 1.1e8);

        PriceFeedMock invalidPriceFeed = new PriceFeedMock(1 ether, 18);
        vm.expectRevert(IncorrectPriceFeedException.selector);
        new BoundedPriceFeed(address(invalidPriceFeed), 1 days, 1.1 ether);

        assertEq(priceFeed.priceFeed(), address(underlyingPriceFeed), "Incorrect priceFeed");
        assertEq(priceFeed.stalenessPeriod(), 1 days, "Incorrect stalenessPeriod");
        assertFalse(priceFeed.skipCheck(), "Incorrect skipCheck");
        assertEq(priceFeed.upperBound(), 1.1e8, "Incorrect upperBound");
    }

    /// @notice U:[BPF-2]: Price feed has correct metadata
    function test_U_BPF_02_price_feed_has_correct_metadata() public {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "TEST / USD bounded price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
    }

    /// @notice U:[BPF-3]: `latestRoundData` works as expected
    function test_U_BPF_03_latestRoundData_works_as_expected() public {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 1e8, "Incorrect answer");

        // upper-bounds answer
        underlyingPriceFeed.setPrice(1.2e8);
        (, answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 1.1e8, "Incorrect upper bounded answer");

        // reverts on stale answer
        underlyingPriceFeed.setParams(0, 0, block.timestamp - 2 days, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.latestRoundData();
    }
}
