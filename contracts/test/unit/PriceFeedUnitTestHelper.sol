// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

contract PriceFeedUnitTestHelper is Test {
    address owner;

    PriceFeedMock underlyingPriceFeed;

    function _setUp() internal {
        underlyingPriceFeed = new PriceFeedMock(2e8, 8);
        underlyingPriceFeed.setParams(0, 0, block.timestamp - 0.5 days, 0);
        vm.mockCall(
            address(underlyingPriceFeed), abi.encodeCall(PriceFeedMock.description, ()), abi.encode("TEST / USD")
        );
        owner = makeAddr("OWNER");
    }
}
