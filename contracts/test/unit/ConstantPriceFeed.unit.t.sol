// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ConstantPriceFeed} from "../../oracles/ConstantPriceFeed.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

contract ConstantPriceFeedUnitTest is Test {
    ConstantPriceFeed priceFeed;
    address token;
    int256 constantPrice;

    function setUp() public {
        token = makeAddr("TOKEN");
        constantPrice = 12345678; // $1.23456789 with 8 decimals

        // Mock token symbol call
        vm.mockCall(token, abi.encodeCall(IERC20Metadata.symbol, ()), abi.encode("TKN"));

        priceFeed = new ConstantPriceFeed(constantPrice, "TKN / USD");
    }

    /// @notice U:[CPF-1]: Price feed initialization works as expected
    function test_U_CPF_1_initialization() public view {
        assertEq(priceFeed.price(), constantPrice, "Incorrect constant price");
        assertEq(priceFeed.description(), "TKN / USD constant price feed", "Incorrect description");
        assertEq(priceFeed.decimals(), 8, "Incorrect decimals");
        assertTrue(priceFeed.skipPriceCheck(), "skipPriceCheck should be true");
        assertEq(priceFeed.contractType(), "PRICE_FEED::CONSTANT", "Incorrect contract type");
    }

    /// @notice U:[CPF-2]: Price feed returns constant price as expected
    function test_U_CPF_2_latestRoundData() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        assertEq(roundId, 0, "Incorrect roundId");
        assertEq(answer, constantPrice, "Incorrect price answer");
        assertEq(startedAt, 0, "Incorrect startedAt");
        assertEq(updatedAt, block.timestamp, "Incorrect updatedAt");
        assertEq(answeredInRound, 0, "Incorrect answeredInRound");
    }

    /// @notice U:[CPF-3]: Price feed serialization works as expected
    function test_U_CPF_3_serialize() public view {
        bytes memory serialized = priceFeed.serialize();
        (int256 serializedPrice) = abi.decode(serialized, (int256));

        assertEq(serializedPrice, constantPrice, "Incorrect serialized price");
    }

    /// @notice U:[CPF-4]: Price feed constructor validates parameters
    function test_U_CPF_4_constructor_validation() public {
        // Test with zero price
        vm.expectRevert(IncorrectPriceException.selector);
        new ConstantPriceFeed(0, "TKN / USD");

        // Test with negative price
        vm.expectRevert(IncorrectPriceException.selector);
        new ConstantPriceFeed(-1, "TKN / USD");
    }
}
