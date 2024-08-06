// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {IMellowVault} from "../../../interfaces/mellow/IMellowVault.sol";

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {MellowChainlinkOracleMock} from "../../mocks/mellow/MellowChainlinkOracleMock.sol";
import {MellowVaultMock} from "../../mocks/mellow/MellowVaultMock.sol";
import {MellowVaultConfiguratorMock} from "../../mocks/mellow/MellowVaultConfiguratorMock.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MellowLRTPriceFeed} from "../../../oracles/mellow/MellowLRTPriceFeed.sol";

contract MellowLRTPriceFeedUnitTest is PriceFeedUnitTestHelper {
    MellowLRTPriceFeed priceFeed;

    ERC20Mock asset;
    MellowVaultMock vault;

    function setUp() public {
        _setUp();

        asset = new ERC20Mock("Test Token", "TEST", 18);

        MellowChainlinkOracleMock chainlinkOracle = new MellowChainlinkOracleMock();
        MellowVaultConfiguratorMock vaultConfigurator = new MellowVaultConfiguratorMock(chainlinkOracle);
        vault = new MellowVaultMock(vaultConfigurator);
        vault.setStack(1.2e18, 1e18);
        chainlinkOracle.setBaseToken(address(vault), address(asset));

        priceFeed = new MellowLRTPriceFeed(
            address(addressProvider), 1.2e18, address(vault), address(underlyingPriceFeed), 1 days
        );
    }

    /// @notice U:[MEL-1]: Price feed works as expected
    function test_U_MEL_01_price_feed_works_as_expected() public {
        // constructor
        assertEq(priceFeed.lpToken(), address(vault), "Incorrect lpToken");
        assertEq(priceFeed.lpContract(), address(vault), "Incorrect lpToken");
        assertEq(priceFeed.lowerBound(), 1.2e18, "Incorrect lower bound");

        // overriden functions
        vm.expectCall(address(vault), abi.encodeCall(IMellowVault.calculateStack, ()));
        assertEq(priceFeed.getLPExchangeRate(), 1.2e18, "Incorrect getLPExchangeRate");
        assertEq(priceFeed.getScale(), 1e18, "Incorrect getScale");
    }
}
