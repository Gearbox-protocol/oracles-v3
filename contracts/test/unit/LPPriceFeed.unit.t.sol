// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {ILPPriceFeed} from "../../interfaces/ILPPriceFeed.sol";
import {
    CallerNotConfiguratorException,
    CallerNotControllerOrConfiguratorException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

import {LPPriceFeedHarness} from "./LPPriceFeed.harness.sol";

/// @title LP price feed unit test
/// @notice U:[LPPF]: Unit tests for LP price feed
contract LPPriceFeedUnitTest is Test {
    LPPriceFeedHarness priceFeed;

    address configurator;

    ERC20Mock lpToken;
    address lpContract;
    AddressProviderV3ACLMock addressProvider;

    function setUp() public {
        configurator = makeAddr("CONFIGURATOR");

        lpToken = new ERC20Mock("Test Token", "TEST", 18);

        lpContract = makeAddr("LP_CONTRACT");

        vm.prank(configurator);
        addressProvider = new AddressProviderV3ACLMock();

        priceFeed = new LPPriceFeedHarness(address(addressProvider), address(lpToken), lpContract);
    }

    /// @notice U:[LPPF-1]: Constructor works as expected
    function test_U_LPPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new LPPriceFeedHarness(address(addressProvider), address(0), lpContract);

        vm.expectRevert(ZeroAddressException.selector);
        new LPPriceFeedHarness(address(addressProvider), address(lpToken), address(0));

        assertEq(priceFeed.lpToken(), address(lpToken), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(lpContract), "Incorrect lpContract");
    }

    /// @notice U:[LPPF-2]: Price feed has correct metadata
    function test_U_LPPF_02_price_feed_has_correct_metadata() public {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "TEST / USD price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
    }

    /// @notice U:[LPPF-3]: `latestRoundData` works as expected
    function test_U_LPPF_03_latestRoundData_works_as_expected() public {
        priceFeed.hackLowerBound(1 ether);
        priceFeed.hackAggregatePrice(2e8);
        priceFeed.hackScale(1 ether);

        // reverts if exchange rate below lower bound
        priceFeed.hackLPExchangeRate(1 ether - 1);
        vm.expectRevert(ILPPriceFeed.ExchangeRateOutOfBoundsException.selector);
        priceFeed.latestRoundData();

        // computes normally if exchange rate within bounds
        priceFeed.hackLPExchangeRate(1.01 ether);
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 2.02e8, "Incorrect answer (exchange rate within bounds)");

        // limits if exchange rate above upper bound
        priceFeed.hackLPExchangeRate(2 ether);
        (, answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 2.04e8, "Incorrect answer (exchange rate above upper bound)");
    }

    /// @notice U:[LPPF-4]: `upperBound` works as expected
    function test_U_LPPF_04_upperBound_works_as_expected() public {
        uint256[3] memory lowerBounds = [uint256(0), 100, 1 ether];
        uint256[3] memory expectedUpperBounds = [uint256(0), 102, 1.02 ether];
        for (uint256 i; i < lowerBounds.length; ++i) {
            priceFeed.hackLowerBound(lowerBounds[i]);
            assertEq(priceFeed.upperBound(), expectedUpperBounds[i], "Incorrect upperBound");
        }
    }

    /// @notice U:[LPPF-6]: `setLimiter` works as expected
    function test_U_LPPF_06_setLimiter_works_as_expected() public {
        priceFeed.hackLPExchangeRate(1 ether);

        // reverts if caller is not controller
        vm.expectRevert(CallerNotControllerOrConfiguratorException.selector);
        priceFeed.setLimiter(0);

        vm.startPrank(configurator);

        // reverts if lower bound is zero
        vm.expectRevert(ILPPriceFeed.LowerBoundCantBeZeroException.selector);
        priceFeed.setLimiter(0);

        // reverts if new bounds don't contain current exchange rate
        vm.expectRevert(ILPPriceFeed.ExchangeRateOutOfBoundsException.selector);
        priceFeed.setLimiter(0.5 ether);
        vm.expectRevert(ILPPriceFeed.ExchangeRateOutOfBoundsException.selector);
        priceFeed.setLimiter(2 ether);

        // works as expected otherwise
        vm.expectEmit(false, false, false, true);
        emit ILPPriceFeed.SetBounds(0.99 ether, 1.0098 ether);
        priceFeed.setLimiter(0.99 ether);

        vm.stopPrank();
    }
}
