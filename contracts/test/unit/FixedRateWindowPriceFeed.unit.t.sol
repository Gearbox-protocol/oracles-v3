// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {
    IncorrectPriceFeedException,
    StalePriceException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {FixedRateWindowPriceFeed, SECONDS_PER_YEAR, WINDOW_SIZE} from "../../oracles/FixedRateWindowPriceFeed.sol";

/// @title Fixed rate window price feed unit test
/// @notice U:[FRWPF]: Unit tests for fixed rate window price feed
contract FixedRateWindowPriceFeedUnitTest is Test {
    FixedRateWindowPriceFeed priceFeed;

    PriceFeedMock underlyingPriceFeed;

    uint16 constant GROWTH_RATE = 1000; // 10% per year
    uint16 constant MAX_GROWTH_RATE = 2000; // 20% per year
    uint256 constant LOWER_BOUND = 1e8;

    function setUp() public {
        underlyingPriceFeed = new PriceFeedMock(1e8, 8);
        underlyingPriceFeed.setParams(0, 0, block.timestamp - 0.5 days, 0);

        priceFeed = new FixedRateWindowPriceFeed(
            address(underlyingPriceFeed), 1 days, GROWTH_RATE, LOWER_BOUND, MAX_GROWTH_RATE, "TEST / USD"
        );
    }

    /// @notice U:[FRWPF-1]: Constructor works as expected
    function test_U_FRWPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new FixedRateWindowPriceFeed(address(0), 1 days, GROWTH_RATE, LOWER_BOUND, MAX_GROWTH_RATE, "");

        PriceFeedMock invalidPriceFeed = new PriceFeedMock(1 ether, 18);
        vm.expectRevert(IncorrectPriceFeedException.selector);
        new FixedRateWindowPriceFeed(address(invalidPriceFeed), 1 days, GROWTH_RATE, LOWER_BOUND, MAX_GROWTH_RATE, "");

        underlyingPriceFeed.setPrice(1e8);
        vm.expectRevert(FixedRateWindowPriceFeed.InvalidGrowthRateException.selector);
        new FixedRateWindowPriceFeed(
            address(underlyingPriceFeed), 1 days, MAX_GROWTH_RATE + 1, LOWER_BOUND, MAX_GROWTH_RATE, ""
        );

        // current price below lower bound
        underlyingPriceFeed.setPrice(int256(LOWER_BOUND) - 1);
        vm.expectRevert(FixedRateWindowPriceFeed.ValueOutOfBoundsException.selector);
        new FixedRateWindowPriceFeed(
            address(underlyingPriceFeed), 1 days, GROWTH_RATE, LOWER_BOUND, MAX_GROWTH_RATE, ""
        );

        // current price above upper bound
        uint256 upperBound = LOWER_BOUND * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR;
        underlyingPriceFeed.setPrice(int256(upperBound) + 1);
        vm.expectRevert(FixedRateWindowPriceFeed.ValueOutOfBoundsException.selector);
        new FixedRateWindowPriceFeed(
            address(underlyingPriceFeed), 1 days, GROWTH_RATE, LOWER_BOUND, MAX_GROWTH_RATE, ""
        );

        assertEq(priceFeed.priceFeed(), address(underlyingPriceFeed), "Incorrect priceFeed");
        assertEq(priceFeed.stalenessPeriod(), 1 days, "Incorrect stalenessPeriod");
        assertFalse(priceFeed.skipCheck(), "Incorrect skipCheck");
        assertEq(priceFeed.growthRate(), GROWTH_RATE, "Incorrect growthRate");
        assertEq(priceFeed.lowerBoundBase(), LOWER_BOUND, "Incorrect lowerBoundBase");
        assertEq(priceFeed.timestampLU(), block.timestamp, "Incorrect timestampLU");
        assertEq(priceFeed.maxGrowthRate(), MAX_GROWTH_RATE, "Incorrect maxGrowthRate");
    }

    /// @notice U:[FRWPF-2]: Price feed has correct metadata
    function test_U_FRWPF_02_price_feed_has_correct_metadata() public view {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "TEST / USD fixed rate window price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
        assertEq(priceFeed.contractType(), "PRICE_FEED::FIXED_RATE_WINDOW", "Incorrect contractType");
    }

    /// @notice U:[FRWPF-3]: `latestRoundData` works as expected
    function test_U_FRWPF_03_latestRoundData_works_as_expected() public {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        assertEq(answer, 1e8, "Incorrect answer");
        assertEq(updatedAt, block.timestamp - 0.5 days, "Incorrect update timestamp");

        // caps answer at upper bound
        uint256 upperBound = LOWER_BOUND * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR;
        underlyingPriceFeed.setPrice(int256(upperBound) + 1e7);
        (, answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, int256(upperBound), "Incorrect upper bounded answer");

        // reverts when answer is below lower bound
        underlyingPriceFeed.setPrice(int256(LOWER_BOUND) - 1);
        vm.expectRevert(FixedRateWindowPriceFeed.ValueOutOfBoundsException.selector);
        priceFeed.latestRoundData();

        // lower bound grows with time
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        underlyingPriceFeed.setParams(0, 0, block.timestamp, 0);

        uint256 grownLowerBound = LOWER_BOUND * (PERCENTAGE_FACTOR + GROWTH_RATE) / PERCENTAGE_FACTOR;
        uint256 grownUpperBound = grownLowerBound * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR;
        assertEq(grownLowerBound, 1.1e8, "Unexpected grown lower bound");

        // still within grown window
        underlyingPriceFeed.setPrice(1.11e8);
        (, answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 1.11e8, "Incorrect answer after growth");

        // below grown lower bound reverts
        underlyingPriceFeed.setPrice(int256(grownLowerBound) - 1);
        vm.expectRevert(FixedRateWindowPriceFeed.ValueOutOfBoundsException.selector);
        priceFeed.latestRoundData();

        // above grown upper bound is capped
        underlyingPriceFeed.setPrice(int256(grownUpperBound) + 1);
        (, answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, int256(grownUpperBound), "Incorrect capped answer after growth");

        // reverts on stale answer
        underlyingPriceFeed.setPrice(1.11e8);
        underlyingPriceFeed.setParams(0, 0, block.timestamp - 2 days, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.latestRoundData();
    }

    /// @notice U:[FRWPF-4]: `setRateAndBounds` works as expected
    function test_U_FRWPF_04_setRateAndBounds_works_as_expected() public {
        address owner = priceFeed.owner();
        address stranger = makeAddr("STRANGER");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(stranger);
        priceFeed.setRateAndBounds(GROWTH_RATE, LOWER_BOUND);

        vm.startPrank(owner);

        vm.expectRevert(FixedRateWindowPriceFeed.InvalidGrowthRateException.selector);
        priceFeed.setRateAndBounds(MAX_GROWTH_RATE + 1, LOWER_BOUND);

        underlyingPriceFeed.setPrice(int256(LOWER_BOUND) - 1);
        vm.expectRevert(FixedRateWindowPriceFeed.ValueOutOfBoundsException.selector);
        priceFeed.setRateAndBounds(GROWTH_RATE, LOWER_BOUND);

        uint256 newLowerBound = 1.01e8;
        uint256 newUpperBound = newLowerBound * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR;
        underlyingPriceFeed.setPrice(int256(newLowerBound));

        vm.expectEmit(false, false, false, true);
        emit FixedRateWindowPriceFeed.SetRateAndBounds(500, newLowerBound, newUpperBound);
        priceFeed.setRateAndBounds(500, newLowerBound);

        assertEq(priceFeed.growthRate(), 500, "Incorrect growthRate");
        assertEq(priceFeed.lowerBoundBase(), newLowerBound, "Incorrect lowerBoundBase");
        assertEq(priceFeed.timestampLU(), block.timestamp, "Incorrect timestampLU");

        vm.stopPrank();
    }
}
