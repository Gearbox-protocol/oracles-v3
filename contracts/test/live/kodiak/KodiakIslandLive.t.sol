// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

import {KodiakIslandPriceFeed} from "../../../oracles/kodiak/KodiakIslandPriceFeed.sol";
import {IKodiakIsland} from "../../../interfaces/kodiak/IKodiakIsland.sol";

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract KodiakIslandLiveTest is Test {
    function test_kodiakIsland() public {
        address kodiakIsland = 0x9659dc8c1565E0bd82627267e3b4eEd1a377ebE6;
        address priceFeed0 = 0xD15862FC3D5407A03B696548b6902D6464A69b8c;
        address priceFeed1 = 0x3FCFA6FD31FaD7E1681B19b7bDc43b9Bc31A0788;

        uint32 stalenessPeriod0 = 1 days;
        uint32 stalenessPeriod1 = 1 days;

        KodiakIslandPriceFeed priceFeed = new KodiakIslandPriceFeed(
            kodiakIsland, priceFeed0, priceFeed1, stalenessPeriod0, stalenessPeriod1, "WBERA/WETH"
        );

        priceFeed.latestRoundData();
    }
}
