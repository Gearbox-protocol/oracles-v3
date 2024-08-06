// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

import {
    IncorrectPriceFeedException,
    StalePriceException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

import {SingleAssetLPPriceFeedHarness} from "./SingleAssetLPPriceFeed.harness.sol";

/// @title Single-asset LP price feed unit test
/// @notice U:[SAPF]: Unit tests for single-asset LP price feed
contract SingleAssetLPPriceFeedUnitTest is Test {
    SingleAssetLPPriceFeedHarness priceFeed;

    address lpToken;
    address lpContract;
    PriceFeedMock underlyingPriceFeed;
    AddressProviderV3ACLMock addressProvider;

    function setUp() public {
        lpToken = makeAddr("LP_TOKEN");
        lpContract = makeAddr("LP_CONTRACT");

        addressProvider = new AddressProviderV3ACLMock();

        underlyingPriceFeed = new PriceFeedMock(1e8, 8);

        priceFeed = new SingleAssetLPPriceFeedHarness(
            address(addressProvider), address(lpToken), address(lpContract), address(underlyingPriceFeed), 1 days
        );
    }

    /// @notice U:[SAPF-1]: Constructor works as expected
    function test_U_SAPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new SingleAssetLPPriceFeedHarness(
            address(addressProvider), address(lpToken), address(lpContract), address(0), 1 days
        );

        PriceFeedMock invalidPriceFeed = new PriceFeedMock(1 ether, 18);
        vm.expectRevert(IncorrectPriceFeedException.selector);
        new SingleAssetLPPriceFeedHarness(
            address(addressProvider), address(lpToken), address(lpContract), address(invalidPriceFeed), 1 days
        );

        assertEq(priceFeed.lpToken(), lpToken, "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), lpContract, "Incorrect lpContract");
        assertEq(priceFeed.priceFeed(), address(underlyingPriceFeed), "Incorrect priceFeed");
        assertEq(priceFeed.stalenessPeriod(), 1 days, "Incorrect stalenessPeriod");
        assertFalse(priceFeed.skipCheck(), "Incorrect skipCheck");
    }

    /// @notice U:[SAPF-2]: `getAggregatePrice` works as expected
    function test_U_SAPF_02_getAggregatePrice_works_as_expected() public {
        // returns same answer as underlying price feed
        int256 answer = priceFeed.getAggregatePrice();
        assertEq(answer, 1e8, "Incorrect answer");

        // reverts on stale answer
        underlyingPriceFeed.setParams(0, 0, block.timestamp - 2 days, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.getAggregatePrice();
    }
}
