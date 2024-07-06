// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {ILPPriceFeedEvents, ILPPriceFeedExceptions} from "../../interfaces/ILPPriceFeed.sol";

import {
    CallerNotConfiguratorException,
    CallerNotControllerOrConfiguratorException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

import {LPPriceFeedHarness} from "./LPPriceFeed.harness.sol";

/// @title LP price feed unit test
/// @notice U:[LPPF]: Unit tests for LP price feed
contract LPPriceFeedUnitTest is Test, ILPPriceFeedEvents, ILPPriceFeedExceptions {
    LPPriceFeedHarness priceFeed;

    address configurator;

    ERC20Mock lpToken;
    address lpContract;
    address priceOracle;
    PriceFeedMock reserveFeed;
    AddressProviderV3ACLMock addressProvider;

    function setUp() public {
        configurator = makeAddr("CONFIGURATOR");

        lpToken = new ERC20Mock("Test Token", "TEST", 18);

        lpContract = makeAddr("LP_CONTRACT");

        priceOracle = makeAddr("PRICE_ORACLE");
        vm.mockCall(priceOracle, abi.encodeCall(IVersion.version, ()), abi.encode(uint256(3_00)));

        reserveFeed = new PriceFeedMock(2.02e8, 8);

        vm.startPrank(configurator);
        addressProvider = new AddressProviderV3ACLMock();
        addressProvider.setAddress("PRICE_ORACLE", priceOracle, true);
        vm.stopPrank();

        priceFeed = new LPPriceFeedHarness(address(addressProvider), priceOracle, address(lpToken), lpContract);
    }

    /// @notice U:[LPPF-1]: Constructor works as expected
    function test_U_LPPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new LPPriceFeedHarness(address(0), priceOracle, address(lpToken), lpContract);

        vm.expectRevert(ZeroAddressException.selector);
        new LPPriceFeedHarness(address(addressProvider), address(0), address(lpToken), lpContract);

        vm.expectRevert(ZeroAddressException.selector);
        new LPPriceFeedHarness(address(addressProvider), address(priceOracle), address(0), lpContract);

        vm.expectRevert(ZeroAddressException.selector);
        new LPPriceFeedHarness(address(addressProvider), address(priceOracle), address(lpToken), address(0));

        assertEq(priceFeed.priceOracle(), priceOracle, "Incorrect priceOracle");
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
        vm.expectRevert(ExchangeRateOutOfBoundsException.selector);
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

    /// @notice U:[LPPF-5]: `allowBoundsUpdate` and `forbidBoundsUpdate` work as expected
    function test_U_LPPF_05_allowBoundsUpdate_and_forbidBoundsUpdate_work_as_expected() public {
        // reverts if caller is not configurator
        vm.expectRevert(CallerNotConfiguratorException.selector);
        priceFeed.allowBoundsUpdate();

        // works as expected otherwise
        vm.expectEmit(false, false, false, true);
        emit SetUpdateBoundsAllowed(true);

        vm.prank(configurator);
        priceFeed.allowBoundsUpdate();

        assertTrue(priceFeed.updateBoundsAllowed(), "Incorrect updateBoundsAllowed");

        // reverts if caller is not controller
        vm.expectRevert(CallerNotControllerOrConfiguratorException.selector);
        priceFeed.forbidBoundsUpdate();

        // works as expected otherwise
        vm.expectEmit(false, false, false, true);
        emit SetUpdateBoundsAllowed(false);

        vm.prank(configurator);
        priceFeed.forbidBoundsUpdate();

        assertFalse(priceFeed.updateBoundsAllowed(), "Incorrect updateBoundsAllowed");
    }

    /// @notice U:[LPPF-6]: `setLimiter` works as expected
    function test_U_LPPF_06_setLimiter_works_as_expected() public {
        priceFeed.hackLPExchangeRate(1 ether);

        // reverts if caller is not controller
        vm.expectRevert(CallerNotControllerOrConfiguratorException.selector);
        priceFeed.setLimiter(0);

        vm.startPrank(configurator);

        // reverts if lower bound is zero
        vm.expectRevert(LowerBoundCantBeZeroException.selector);
        priceFeed.setLimiter(0);

        // reverts if new bounds don't contain current exchange rate
        vm.expectRevert(ExchangeRateOutOfBoundsException.selector);
        priceFeed.setLimiter(0.5 ether);
        vm.expectRevert(ExchangeRateOutOfBoundsException.selector);
        priceFeed.setLimiter(2 ether);

        // works as expected otherwise
        vm.expectEmit(false, false, false, true);
        emit SetBounds(0.99 ether, 1.0098 ether);
        priceFeed.setLimiter(0.99 ether);

        vm.stopPrank();
    }

    /// @notice U:[LPPF-7]: `updateBounds` works as expected
    function test_U_LPPF_07_updateBoudns_works_as_expected() public {
        priceFeed.hackAggregatePrice(2e8);
        priceFeed.hackLowerBound(1 ether);
        priceFeed.hackScale(1 ether);

        // permissionless bounds update is forbidden (oh the irony)
        vm.expectRevert(UpdateBoundsNotAllowedException.selector);
        priceFeed.updateBounds("some data");

        priceFeed.hackUpdateBoundsAllowed(true);

        // cooldown hasn't passed
        priceFeed.hackLastBoundsUpdate(block.timestamp);
        vm.expectRevert(UpdateBoundsBeforeCooldownException.selector);
        priceFeed.updateBounds("some data");

        priceFeed.hackLastBoundsUpdate(block.timestamp - 1 days);

        // reserve feed is self
        vm.mockCall(
            priceOracle,
            abi.encodeCall(IPriceOracleV3.reservePriceFeeds, (address(lpToken))),
            abi.encode(address(priceFeed))
        );
        vm.expectRevert(ReserveFeedMustNotBeSelfException.selector);
        priceFeed.updateBounds("some data");

        vm.mockCall(
            priceOracle, abi.encodeCall(IPriceOracleV3.reservePriceFeeds, (address(lpToken))), abi.encode(reserveFeed)
        );

        // reserve exchange rate is out of bounds
        vm.mockCall(priceOracle, abi.encodeCall(IPriceOracleV3.getReservePrice, (address(lpToken))), abi.encode(2.05e8));
        vm.expectRevert(ExchangeRateOutOfBoundsException.selector);
        priceFeed.updateBounds("some data");

        vm.mockCall(priceOracle, abi.encodeCall(IPriceOracleV3.getReservePrice, (address(lpToken))), abi.encode(2.02e8));

        // exchange rate is out of new bounds
        priceFeed.hackLPExchangeRate(0.99 ether);
        vm.expectRevert(ExchangeRateOutOfBoundsException.selector);
        priceFeed.updateBounds("some data");

        priceFeed.hackLPExchangeRate(1.01 ether);

        for (uint256 i; i < 2; ++i) {
            bool isUpdatable = i == 1;
            if (isUpdatable) {
                vm.mockCall(address(reserveFeed), abi.encodeCall(IUpdatablePriceFeed.updatable, ()), abi.encode(true));
                vm.mockCall(address(reserveFeed), abi.encodeCall(IUpdatablePriceFeed.updatePrice, ("some data")), "");

                vm.expectCall(address(reserveFeed), abi.encodeCall(IUpdatablePriceFeed.updatePrice, ("some data")));
            } else {
                vm.mockCallRevert(
                    address(reserveFeed),
                    abi.encode(IUpdatablePriceFeed.updatePrice.selector),
                    "updatePrice should not be called"
                );
            }

            vm.expectCall(priceOracle, abi.encodeCall(IPriceOracleV3.reservePriceFeeds, (address(lpToken))));
            vm.expectCall(priceOracle, abi.encodeCall(IPriceOracleV3.getReservePrice, (address(lpToken))));

            vm.expectEmit(false, false, false, true);
            // lower bound 0.9999 = 2.02 / 2 * 0.99; upper bound 1.019898 = 0.9999 * 1.02
            emit SetBounds(0.9999 ether, 1.019898 ether);

            priceFeed.updateBounds("some data");
            assertEq(priceFeed.lowerBound(), 0.9999 ether, "Incorrect lowerBound");

            priceFeed.hackLastBoundsUpdate(block.timestamp - 1 days);
        }
    }
}
