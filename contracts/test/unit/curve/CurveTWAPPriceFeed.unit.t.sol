// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {PriceFeedUnitTestHelper} from "../PriceFeedUnitTestHelper.sol";

import {CurvePoolMock} from "../../mocks/curve/CurvePoolMock.sol";

import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";
import {CurveTWAPPriceFeed} from "../../../oracles/curve/CurveTWAPPriceFeed.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract CurveTWAPPriceFeedUnitTest is PriceFeedUnitTestHelper {
    CurveTWAPPriceFeed priceFeed;
    CurvePoolMock curvePool;
    address token;
    uint256 lowerBound;
    uint256 upperBound;

    function setUp() public {
        _setUp();

        token = makeAddr("token");
        vm.mockCall(token, abi.encodeCall(IERC20Metadata.symbol, ()), abi.encode("TOKEN"));

        curvePool = new CurvePoolMock();
        curvePool.hack_price_oracle(1.03 ether);

        lowerBound = 1.02 ether;
        upperBound = 1.05 ether;

        priceFeed = new CurveTWAPPriceFeed(
            lowerBound,
            upperBound,
            false,
            token,
            address(curvePool),
            address(underlyingPriceFeed),
            1 days,
            "TOKEN / USDC"
        );
    }

    /// @notice U:[CTWAP-1]: Price feed works as expected
    function test_U_CTWAP_1_price_feed_works_as_expected() public {
        // constructor
        assertEq(priceFeed.token(), token, "Incorrect token address");
        assertEq(priceFeed.pool(), address(curvePool), "Incorrect pool address");
        assertEq(priceFeed.priceFeed(), address(underlyingPriceFeed), "Incorrect price feed");
        assertEq(priceFeed.lowerBound(), lowerBound, "Incorrect lower bound");
        assertEq(priceFeed.upperBound(), upperBound, "Incorrect upper bound");
        assertEq(priceFeed.description(), "TOKEN / USDC Curve TWAP price feed", "Incorrect description");

        // latestRoundData
        vm.expectCall(address(curvePool), abi.encodeWithSignature("price_oracle()"));
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        assertEq(price, int256((1.03 ether * 2e8) / WAD), "Incorrect price");
        assertEq(updatedAt, block.timestamp - 0.5 days, "Incorrect update timestamp");

        curvePool.hack_withIndex(true);
        vm.expectCall(address(curvePool), abi.encodeWithSignature("price_oracle(uint256)", 0));
        (, int256 price2,,,) = priceFeed.latestRoundData();
        assertEq(price2, int256((1.03 ether * 2e8) / WAD), "Incorrect price");
    }

    /// @notice U:[CTWAP-2]: Price feed handles exchange rate bounds properly
    function test_U_CTWAP_2_price_feed_handles_exchange_rate_bounds() public {
        // Test when exchange rate is below lower bound
        curvePool.hack_price_oracle(1.01 ether); // Below lower bound
        vm.expectRevert(CurveTWAPPriceFeed.CurveOracleOutOfBoundsException.selector);
        priceFeed.latestRoundData();

        // Test when exchange rate equals lower bound
        curvePool.hack_price_oracle(lowerBound);
        (, int256 price,,,) = priceFeed.latestRoundData();
        assertEq(price, int256((lowerBound * 2e8) / WAD), "Incorrect price at lower bound");

        // Test when exchange rate equals upper bound
        curvePool.hack_price_oracle(upperBound);
        (, int256 price2,,,) = priceFeed.latestRoundData();
        assertEq(price2, int256((upperBound * 2e8) / WAD), "Incorrect price at upper bound");

        // Test when exchange rate exceeds upper bound (should be capped)
        curvePool.hack_price_oracle(1.06 ether); // Above upper bound
        (, int256 price3,,,) = priceFeed.latestRoundData();
        assertEq(price3, int256((upperBound * 2e8) / WAD), "Incorrect price when above upper bound");
    }

    /// @notice U:[CTWAP-3]: Price feed constructor validates bounds correctly
    function test_U_CTWAP_3_constructor_validates_bounds() public {
        // Test upper bound < lower bound
        vm.expectRevert(CurveTWAPPriceFeed.UpperBoundTooLowException.selector);
        new CurveTWAPPriceFeed(
            lowerBound,
            lowerBound - 1, // Upper less than lower
            false,
            token,
            address(curvePool),
            address(underlyingPriceFeed),
            1 days,
            "TOKEN / USDC"
        );
    }
}
