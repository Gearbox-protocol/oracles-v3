// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.10;

import {
    PythPriceFeed,
    IPythPriceFeedExceptions,
    MAX_DATA_TIMESTAMP_DELAY_SECONDS,
    MAX_DATA_TIMESTAMP_AHEAD_SECONDS,
    IPythExtended
} from "../../../oracles/updatable/PythPriceFeed.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// TEST
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {PythMock} from "../../mocks/pyth/PythMock.sol";
import {TestHelper} from "@gearbox-protocol/core-v3/contracts/test/lib/helper.sol";

/// @title Pyth price feed unit test
/// @notice U:[PYPF]: Unit tests for Pyth price feed
contract PythPriceFeedUnitTest is TestHelper, IPythPriceFeedExceptions {
    PythPriceFeed pf;
    PythMock pyth;
    address token;

    function setUp() public {
        pyth = new PythMock();
        token = address(new ERC20Mock("USD Coin", "USDC", 6));

        pf = new PythPriceFeed(token, bytes32(uint256(1)), address(pyth), "USDC/USD", 5000);
        vm.deal(address(pf), 100000);
    }

    /// @notice U: [PYPF-1]: constructor sets correct values
    function test_U_PYPF_01_constructor_sets_correct_values() public {
        assertEq(
            pf.description(),
            string(abi.encodePacked("USDC/USD", " Pyth price feed")),
            "Price feed description incorrect"
        );

        assertEq(pf.token(), token, "Price feed token incorrect");

        assertEq(pf.priceFeedId(), bytes32(uint256(1)), "Price feed ID incorrect");

        assertEq(pf.pyth(), address(pyth), "Pyth address incorrect");
    }

    /// @notice U: [PYPF-2]: updatePrice stops early when expected timestamp is older than the last recorded
    function test_U_PYPF_02_updatePrice_stops_early_on_old_timestamp() public {
        pyth.setPriceData(bytes32(uint256(1)), 10 ** 8, 0, -8, block.timestamp + 1000000);

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encode(int64(10 ** 8), block.timestamp + 999999, int32(-8), bytes32(uint256(1)));

        bytes memory updateData = abi.encode(block.timestamp + 999999, payloads);

        pf.updatePrice(updateData);
    }

    /// @notice U: [PYPF-3]: updatePrice reverts if the expected timestamp is too far from the block
    function test_U_PYPF_03_updatePrice_reverts_on_non_current_timestamp() public {
        pyth.setPriceData(bytes32(uint256(1)), 10 ** 8, 0, -8, block.timestamp);

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encode(int64(10 ** 8), block.timestamp + 64000, int32(-8), bytes32(uint256(1)));

        bytes memory updateData = abi.encode(block.timestamp + 64000, payloads);

        vm.expectRevert(PriceTimestampTooFarAheadException.selector);
        pf.updatePrice(updateData);

        pyth.setPriceData(bytes32(uint256(1)), 10 ** 8, 0, -8, block.timestamp - 64001);

        updateData = abi.encode(block.timestamp - 64000, payloads);

        vm.expectRevert(PriceTimestampTooFarBehindException.selector);
        pf.updatePrice(updateData);
    }

    /// @notice U: [PYPF-4]: updatePrice correctly passes data to pyth
    function test_U_PYPF_04_updatePrice_correctly_passes_data() public {
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encode(int64(10 ** 8), block.timestamp, int32(-8), bytes32(uint256(1)));

        bytes memory updateData = abi.encode(block.timestamp, payloads);

        vm.expectEmit(false, false, false, true);

        emit IUpdatablePriceFeed.UpdatePrice(100000000);

        vm.expectCall(address(pyth), abi.encodeCall(IPyth.updatePriceFeeds, (payloads)), 1);
        pf.updatePrice(updateData);
    }

    /// @notice U: [PYPF-5]: updatePrice reverts if the expected timestamp does not match payload timestamp
    function test_U_PYPF_05_updatePrice_reverts_on_incorrect_expected_timestamp() public {
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encode(int64(10 ** 8), block.timestamp + 1, int32(-8), bytes32(uint256(1)));

        bytes memory updateData = abi.encode(block.timestamp, payloads);

        vm.expectRevert(IncorrectExpectedPublishTimestampException.selector);
        pf.updatePrice(updateData);
    }

    /// @notice U: [PYPF-6]: updatePrice reverts on price equal to 0
    function test_U_PYPF_06_updatePrice_reverts_on_price_0() public {
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encode(0, block.timestamp, int32(-8), bytes32(uint256(1)));

        bytes memory updateData = abi.encode(block.timestamp, payloads);

        vm.expectRevert(IncorrectPriceException.selector);
        pf.updatePrice(updateData);
    }

    function test_U_PYPF_07_latestRoundData_correctly_handles_non_standard_expo() public {
        pyth.setPriceData(bytes32(uint256(1)), 10 ** 6, 0, -6, block.timestamp);

        (, int256 price,,,) = pf.latestRoundData();

        assertEq(price, 10 ** 8, "Incorrect price when pyth decimals are below 8");

        pyth.setPriceData(bytes32(uint256(1)), 10 ** 18, 0, -18, block.timestamp);

        (, price,,,) = pf.latestRoundData();

        assertEq(price, 10 ** 8, "Incorrect price when pyth decimals are above 8");

        pyth.setPriceData(bytes32(uint256(1)), 100, 0, 0, block.timestamp);

        (, price,,,) = pf.latestRoundData();

        assertEq(price, 100 * 10 ** 8, "Incorrect price when pyth decimals are 0");
    }

    function test_U_PYPF_08_latestRoundData_reverts_on_too_high_conf_to_price_ratio() public {
        pyth.setPriceData(bytes32(uint256(1)), 10 ** 8, 10000000000000000000, -8, block.timestamp - 64001);

        vm.expectRevert(ConfToPriceRatioTooHighException.selector);
        pf.latestRoundData();
    }
}
