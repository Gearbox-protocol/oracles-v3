// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {ERC4626Mock} from "../../mocks/erc4626/ERC4626Mock.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {ERC4626PriceFeed} from "../../../oracles/erc4626/ERC4626PriceFeed.sol";

contract ERC4626PriceFeedUnitTest is PriceFeedUnitTestHelper {
    ERC4626PriceFeed priceFeed;

    ERC20Mock asset;
    ERC4626Mock vault;

    function setUp() public {
        _setUp();

        asset = new ERC20Mock("Test Token", "TEST", 6);
        vault = new ERC4626Mock(address(asset), "Test Token Vault", "vTEST");
        vault.hackPricePerShare(1.03e6);

        priceFeed = new ERC4626PriceFeed(
            address(addressProvider), priceOracle, 1.02e6, address(vault), address(underlyingPriceFeed), 1 days
        );
    }

    /// @notice U:[TV-1]: Price feed works as expected
    function test_U_TV_01_price_feed_works_as_expected() public {
        // constructor
        assertEq(priceFeed.lpToken(), address(vault), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(vault), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.02e6, "Incorrect lower bound");

        // overriden functions
        vm.expectCall(address(vault), abi.encodeCall(IERC4626.convertToAssets, (1e6)));
        assertEq(priceFeed.getLPExchangeRate(), 1.03e6, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1e6, "Incorrect getScale");
    }
}
