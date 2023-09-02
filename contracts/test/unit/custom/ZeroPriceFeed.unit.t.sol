// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {ZeroPriceFeed} from "../../../oracles/custom/ZeroPriceFeed.sol";

/// @title Zero price feed unit test
/// @notice U:[ZPF]: Unit tests for zero price feed
contract ZeroPriceFeedUnitTest is Test {
    ZeroPriceFeed priceFeed;

    function setUp() public {
        priceFeed = new ZeroPriceFeed();
    }

    /// @notice U:[ZPF-1]: Price feed has correct metadata
    function test_U_ZPF_01_price_feed_has_correct_metadata() public {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "Zero price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
    }

    /// @notice U:[ZPF-2]: `latestRoundData` works as expected
    function test_U_ZPF_02_latestRoundData_works_as_expected() public {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 0, "Incorrect answer");
    }
}
