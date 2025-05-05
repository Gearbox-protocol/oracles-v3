// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {
    IncorrectParameterException,
    IncorrectPriceFeedException,
    StalePriceException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import {FixedMultiplierPriceFeed} from "../../oracles/FixedMultiplierPriceFeed.sol";
import {IFixedMultiplierPriceFeed} from "../../interfaces/IFixedMultiplierPriceFeed.sol";

/// @title Fixed multiplier price feed unit test
/// @notice U:[FRPF]: Unit tests for fixed multiplier price feed
contract FixedMultiplierPriceFeedUnitTest is Test {
    FixedMultiplierPriceFeed priceFeed;

    PriceFeedMock underlyingPriceFeed;
    ERC20Mock lpToken;

    address owner = makeAddr("owner");
    uint256 initialMultiplier = 0.5e18;
    uint256 multiplierScale = 1e18;
    uint32 stalenessPeriod = 1 days;

    function setUp() public {
        underlyingPriceFeed = new PriceFeedMock(1e8, 8);
        lpToken = new ERC20Mock("LP Token", "LP", 18);

        priceFeed = new FixedMultiplierPriceFeed(
            owner, initialMultiplier, multiplierScale, address(underlyingPriceFeed), stalenessPeriod, address(lpToken)
        );
    }

    /// @notice U:[FRPF-1]: Constructor works as expected
    function test_U_FRPF_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new FixedMultiplierPriceFeed(
            owner, initialMultiplier, multiplierScale, address(0), stalenessPeriod, address(lpToken)
        );

        vm.expectRevert(ZeroAddressException.selector);
        new FixedMultiplierPriceFeed(
            owner, initialMultiplier, multiplierScale, address(underlyingPriceFeed), stalenessPeriod, address(0)
        );

        // Create price feed with invalid decimals
        PriceFeedMock invalidPriceFeed = new PriceFeedMock(1 ether, 18);
        vm.expectRevert(IncorrectPriceFeedException.selector);
        new FixedMultiplierPriceFeed(
            owner, initialMultiplier, multiplierScale, address(invalidPriceFeed), stalenessPeriod, address(lpToken)
        );

        assertEq(priceFeed.priceFeed(), address(underlyingPriceFeed), "Incorrect priceFeed");
        assertEq(priceFeed.stalenessPeriod(), stalenessPeriod, "Incorrect stalenessPeriod");
        assertFalse(priceFeed.skipCheck(), "Incorrect skipCheck");
        assertEq(priceFeed.multiplier(), initialMultiplier, "Incorrect multiplier");
        assertEq(priceFeed.scale(), multiplierScale, "Incorrect scale");
        assertEq(priceFeed.owner(), owner, "Incorrect owner");
        assertEq(priceFeed.lpToken(), address(lpToken), "Incorrect lpToken");
    }

    /// @notice U:[FRPF-2]: Price feed has correct metadata
    function test_U_FRPF_02_price_feed_has_correct_metadata() public view {
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertEq(priceFeed.description(), "LP / USD LP fixed multiplier price feed", "Incorrect description");
        assertTrue(priceFeed.skipPriceCheck(), "Incorrect skipPriceCheck");
        assertEq(priceFeed.contractType(), "PRICE_FEED::FIXED_MULTIPLIER", "Incorrect contractType");
        assertEq(priceFeed.version(), 3_10, "Incorrect version");
    }

    /// @notice U:[FRPF-3]: `latestRoundData` works as expected
    function test_U_FRPF_03_latestRoundData_works_as_expected() public {
        // With initial multiplier 0.5e18/1e18, 1e8 price should be scaled to 0.5e8
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 0.5e8, "Incorrect answer");

        // Update underlying price and check new value
        underlyingPriceFeed.setPrice(2e8);
        (, answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 1e8, "Incorrect answer after price update");

        // Reverts on stale answer
        underlyingPriceFeed.setParams(0, 0, block.timestamp - 2 days, 0);
        vm.expectRevert(StalePriceException.selector);
        priceFeed.latestRoundData();
    }

    /// @notice U:[FRPF-4]: `setMultiplier` works as expected
    function test_U_FRPF_04_setMultiplier_works_as_expected() public {
        // Only owner can set multiplier
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert("Ownable: caller is not the owner");
        priceFeed.setMultiplier(0.75e18);

        // Cannot set multiplier to 0
        vm.prank(owner);
        vm.expectRevert(IFixedMultiplierPriceFeed.MultiplierCantBeZeroException.selector);
        priceFeed.setMultiplier(0);

        // Set new multiplier and verify it works
        vm.prank(owner);
        priceFeed.setMultiplier(0.75e18);
        assertEq(priceFeed.multiplier(), 0.75e18, "Multiplier not updated");

        // Check that the new multiplier affects price calculation
        underlyingPriceFeed.setPrice(1e8);
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, 0.75e8, "Incorrect answer with new multiplier");
    }

    /// @notice U:[FRPF-5]: `serialize` works as expected
    function test_U_FRPF_05_serialize_works_as_expected() public view {
        bytes memory serialized = priceFeed.serialize();
        (address _lpToken, uint256 _multiplier, address _priceFeed) =
            abi.decode(serialized, (address, uint256, address));

        assertEq(_lpToken, address(lpToken), "Incorrect serialized lpToken");
        assertEq(_multiplier, initialMultiplier, "Incorrect serialized multiplier");
        assertEq(_priceFeed, address(underlyingPriceFeed), "Incorrect serialized priceFeed");
    }
}
