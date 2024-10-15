// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

contract PriceFeedUnitTestHelper is Test {
    address configurator;

    PriceFeedMock underlyingPriceFeed;
    AddressProviderV3ACLMock addressProvider;

    function _setUp() internal {
        underlyingPriceFeed = new PriceFeedMock(2e8, 8);
        vm.mockCall(
            address(underlyingPriceFeed), abi.encodeCall(PriceFeedMock.description, ()), abi.encode("TEST / USD")
        );

        configurator = makeAddr("CONFIGURATOR");
        vm.prank(configurator);
        addressProvider = new AddressProviderV3ACLMock();
    }
}
