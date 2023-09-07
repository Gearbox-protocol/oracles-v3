// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {IVersion} from "@gearbox-protocol/core-v2/contracts/interfaces/IVersion.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

contract PriceFeedUnitTestHelper is Test {
    address priceOracle;
    address configurator;

    PriceFeedMock underlyingPriceFeed;
    AddressProviderV3ACLMock addressProvider;

    function _setUp() internal {
        priceOracle = makeAddr("PRICE_ORACLE");
        vm.mockCall(priceOracle, abi.encodeCall(IVersion.version, ()), abi.encode(uint256(3_00)));

        underlyingPriceFeed = new PriceFeedMock(2e8, 8);
        vm.mockCall(
            address(underlyingPriceFeed), abi.encodeCall(PriceFeedMock.description, ()), abi.encode("TEST / USD")
        );

        configurator = makeAddr("CONFIGURATOR");
        vm.startPrank(configurator);
        addressProvider = new AddressProviderV3ACLMock();
        addressProvider.setAddress("PRICE_ORACLE", priceOracle, true);
        vm.stopPrank();
    }
}
