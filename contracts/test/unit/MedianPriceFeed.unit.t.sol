// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {
    IncorrectPriceFeedException,
    StalePriceException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {PriceFeedParams} from "../../oracles/PriceFeedParams.sol";
import {MedianPriceFeed} from "../../oracles/MedianPriceFeed.sol";

/// @title Median price feed unit test
/// @notice U:[MPF]: Unit tests for median price feed
contract MedianPriceFeedUnitTest is Test {
    MedianPriceFeed priceFeed;

    PriceFeedMock priceFeed0;
    PriceFeedMock priceFeed1;
    PriceFeedMock priceFeed2;

    function setUp() public {
        priceFeed0 = new PriceFeedMock(1e8, 8);
        priceFeed1 = new PriceFeedMock(1.1e8, 8);
        priceFeed2 = new PriceFeedMock(0.9e8, 8);

        priceFeed0.setParams(0, 0, block.timestamp - 0.3 days, 0);
        priceFeed1.setParams(0, 0, block.timestamp - 0.5 days, 0);
        priceFeed2.setParams(0, 0, block.timestamp - 0.1 days, 0);

        priceFeed = new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(priceFeed1), 1 days),
                PriceFeedParams(address(priceFeed2), 1 days)
            ],
            "TEST / USD"
        );
    }

    /// @notice U:[MPF-1]: Constructor works as expected
    function test_U_MPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new MedianPriceFeed(
            [
                PriceFeedParams(address(0), 1 days),
                PriceFeedParams(address(priceFeed1), 1 days),
                PriceFeedParams(address(priceFeed2), 1 days)
            ],
            ""
        );

        PriceFeedMock invalidPriceFeed = new PriceFeedMock(1 ether, 18);
        vm.expectRevert(IncorrectPriceFeedException.selector);
        new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(invalidPriceFeed), 1 days),
                PriceFeedParams(address(0), 0)
            ],
            ""
        );

        assertEq(priceFeed.priceFeed0(), address(priceFeed0), "Incorrect priceFeed0");
        assertEq(priceFeed.priceFeed1(), address(priceFeed1), "Incorrect priceFeed1");
        assertEq(priceFeed.priceFeed2(), address(priceFeed2), "Incorrect priceFeed2");

        assertEq(priceFeed.stalenessPeriod0(), 1 days, "Incorrect stalenessPeriod0");
        assertEq(priceFeed.stalenessPeriod1(), 1 days, "Incorrect stalenessPeriod1");
        assertEq(priceFeed.stalenessPeriod2(), 1 days, "Incorrect stalenessPeriod2");

        assertFalse(priceFeed.skipCheck0(), "Incorrect skipCheck0");
        assertFalse(priceFeed.skipCheck1(), "Incorrect skipCheck1");
        assertFalse(priceFeed.skipCheck2(), "Incorrect skipCheck2");

        assertEq(priceFeed.nFeeds(), 3, "Incorrect nFeeds");

        MedianPriceFeed oneFeed = new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(0), 0),
                PriceFeedParams(address(0), 0)
            ],
            ""
        );
        assertEq(oneFeed.nFeeds(), 1, "Incorrect nFeeds for one feed");

        MedianPriceFeed twoFeeds = new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(priceFeed1), 1 days),
                PriceFeedParams(address(0), 0)
            ],
            ""
        );
        assertEq(twoFeeds.nFeeds(), 2, "Incorrect nFeeds for two feeds");
        assertEq(twoFeeds.stalenessPeriod2(), 0, "Incorrect stalenessPeriod2 for two feeds");
    }

    /// @notice U:[MPF-2]: Price feed has correct metadata
    function test_U_MPF_02_price_feed_has_correct_metadata() public view {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "TEST / USD median price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
        assertEq(priceFeed.contractType(), "PRICE_FEED::MEDIAN", "Incorrect contractType");
    }

    /// @notice U:[MPF-3]: `latestRoundData` works as expected
    function test_U_MPF_03_latestRoundData_works_as_expected() public {
        // three feeds: median of 0.9e8, 1e8, 1.1e8 is 1e8; earliest updatedAt wins
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        assertEq(answer, 1e8, "Incorrect answer");
        assertEq(updatedAt, block.timestamp - 0.5 days, "Incorrect updatedAt");

        // two feeds: average
        MedianPriceFeed twoFeeds = new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(priceFeed1), 1 days),
                PriceFeedParams(address(0), 0)
            ],
            ""
        );
        priceFeed0.setPrice(1e8);
        priceFeed1.setPrice(1.1e8);
        (, answer,,,) = twoFeeds.latestRoundData();
        assertEq(answer, 1.05e8, "Incorrect two-feed average");

        // one feed: passthrough
        MedianPriceFeed oneFeed = new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(0), 0),
                PriceFeedParams(address(0), 0)
            ],
            ""
        );
        priceFeed0.setPrice(1.23e8);
        (, answer,,,) = oneFeed.latestRoundData();
        assertEq(answer, 1.23e8, "Incorrect one-feed answer");

        // reverts on stale underlying answer
        priceFeed0.setPrice(1e8);
        priceFeed0.setParams(0, 0, block.timestamp - 2 days, 0);
        priceFeed1.setParams(0, 0, block.timestamp, 0);
        priceFeed2.setParams(0, 0, block.timestamp, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.latestRoundData();
    }

    /// @notice U:[MPF-4]: Fuzz: median of three feeds is computed correctly
    function test_U_MPF_04_fuzz_median_of_three_feeds_is_computed_correctly(int256 a, int256 b, int256 c) public {
        a = bound(a, 1, type(int256).max / 2);
        b = bound(b, a, type(int256).max / 2);
        c = bound(c, b, type(int256).max / 2);

        // randomly permute (a, b, c) onto the three feeds
        int256[3] memory values = [a, b, c];
        bytes32 seed = keccak256(abi.encode(a, b, c));
        for (uint256 i = 0; i < 3; ++i) {
            uint256 j = i + (uint256(seed) % (3 - i));
            (values[i], values[j]) = (values[j], values[i]);
            seed = keccak256(abi.encode(seed));
        }

        priceFeed0.setPrice(values[0]);
        priceFeed1.setPrice(values[1]);
        priceFeed2.setPrice(values[2]);
        priceFeed0.setParams(0, 0, block.timestamp, 0);
        priceFeed1.setParams(0, 0, block.timestamp, 0);
        priceFeed2.setParams(0, 0, block.timestamp, 0);

        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, b, "Incorrect median");
    }

    /// @notice U:[MPF-5]: Fuzz: average of two feeds is computed correctly
    function test_U_MPF_05_fuzz_average_of_two_feeds_is_computed_correctly(int256 a, int256 b) public {
        a = bound(a, 1, type(int256).max / 2);
        b = bound(b, 1, type(int256).max / 2);

        MedianPriceFeed twoFeeds = new MedianPriceFeed(
            [
                PriceFeedParams(address(priceFeed0), 1 days),
                PriceFeedParams(address(priceFeed1), 1 days),
                PriceFeedParams(address(0), 0)
            ],
            ""
        );

        priceFeed0.setPrice(a);
        priceFeed1.setPrice(b);
        priceFeed0.setParams(0, 0, block.timestamp, 0);
        priceFeed1.setParams(0, 0, block.timestamp, 0);

        (, int256 answer,,,) = twoFeeds.latestRoundData();
        assertEq(answer, (a + b) / 2, "Incorrect average");
    }
}
