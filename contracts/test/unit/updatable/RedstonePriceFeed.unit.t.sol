// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {
    RedstonePriceFeed,
    IRedstonePriceFeedEvents,
    IRedstonePriceFeedExceptions,
    MAX_DATA_TIMESTAMP_DELAY_SECONDS,
    MAX_DATA_TIMESTAMP_AHEAD_SECONDS
} from "../../../oracles/updatable/RedstonePriceFeed.sol";
import {RedstoneConstants} from "@redstone-finance/evm-connector/contracts/core/RedstoneConstants.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

// TEST
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {TestHelper} from "@gearbox-protocol/core-v3/contracts/test/lib/helper.sol";

/// @title Redstone price feed unit test
/// @notice U:[RPF]: Unit tests for Redstone price feed
contract RedstonePriceFeedUnitTest is
    TestHelper,
    IRedstonePriceFeedExceptions,
    IRedstonePriceFeedEvents,
    RedstoneConstants
{
    RedstonePriceFeed pf;
    address[10] signers;
    uint256[10] signerKeys;

    uint72 constant REDSTONE_MARKER = 0x000002ed57011e0000;

    function setUp() public {
        _generateSigners(10);

        pf = new RedstonePriceFeed(
            address(new ERC20Mock("USD Coin", "USDC", 6)),
            bytes32("USDC"),
            signers,
            10
        );
    }

    function _generateSigners(uint8 _numSigners) internal {
        for (uint256 i = 0; i < _numSigners; ++i) {
            signerKeys[i] = uint256(keccak256(abi.encodePacked("SIGNER", i)));
            signers[i] = vm.addr(signerKeys[i]);
        }
    }

    function _generateRedstonePayload(
        bytes32 dataFeedId,
        uint256 value,
        uint48 timestamp,
        uint256 numDataPackages,
        bool oneTimestampWrong,
        bool oneSignerWrong
    ) internal view returns (bytes memory payload) {
        // GENERATING SIGNED DATA PACKAGES

        for (uint256 i = 0; i < numDataPackages; ++i) {
            bytes memory dataPackage = "";

            dataPackage = abi.encodePacked(dataPackage, dataFeedId, value);

            uint48 storedTimestamp = i == 0 && oneTimestampWrong ? timestamp + 2000 : timestamp;

            dataPackage = abi.encodePacked(dataPackage, storedTimestamp);
            dataPackage = abi.encodePacked(dataPackage, uint32(32));
            dataPackage = abi.encodePacked(dataPackage, uint24(1));

            uint256 signerKey = i == 0 && oneSignerWrong ? uint256(keccak256("WRONG")) : signerKeys[i];

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, keccak256(dataPackage));

            dataPackage = abi.encodePacked(dataPackage, r, s, v);

            payload = abi.encodePacked(payload, dataPackage);
        }

        payload = abi.encodePacked(payload, uint16(numDataPackages));

        uint256 payloadSize = payload.length;

        // GENERATING UNSIGNED MESSAGE

        bytes memory message = bytes("Hello Redstone");

        uint256 bytesToPad = 32 - (payloadSize + message.length + 3 + 9) % 32;
        bytesToPad = bytesToPad % 32;

        for (uint256 i = 0; i < bytesToPad; ++i) {
            message = abi.encodePacked(message, uint8(1));
        }

        payload = abi.encodePacked(payload, message, uint24(message.length), REDSTONE_MARKER);
    }

    /// @notice U: [RPF-1]: constructor sets correct values
    function test_U_RPF_01_constructor_sets_correct_values() public {
        assertEq(pf.description(), "USDC / USD Redstone price feed", "Incorrect description");

        assertEq(pf.dataFeedId(), bytes32("USDC"), "Incorrect data feed id");

        assertEq(pf.signerAddress0(), signers[0], "Incorrect signer address 0");

        assertEq(pf.signerAddress1(), signers[1], "Incorrect signer address 1");

        assertEq(pf.signerAddress2(), signers[2], "Incorrect signer address 2");

        assertEq(pf.signerAddress3(), signers[3], "Incorrect signer address 3");

        assertEq(pf.signerAddress4(), signers[4], "Incorrect signer address 4");

        assertEq(pf.signerAddress5(), signers[5], "Incorrect signer address 5");

        assertEq(pf.signerAddress6(), signers[6], "Incorrect signer address 6");

        assertEq(pf.signerAddress7(), signers[7], "Incorrect signer address 7");

        assertEq(pf.signerAddress8(), signers[8], "Incorrect signer address 8");

        assertEq(pf.signerAddress9(), signers[9], "Incorrect signer address 9");

        assertEq(pf.getUniqueSignersThreshold(), 10, "Incorrect signers threshold");
    }

    /// @notice U: [RPF-2]: updatePrice works correctly on correct payload
    function test_U_RPF_02_updatePrice_successfully_updates_price_with_correct_payload() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 100000000, uint48((block.timestamp - 1) * 1000), 10, false, false);

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectEmit(false, false, false, true);

        emit UpdatePrice(100000000);

        pf.updatePrice(data);

        assertEq(pf.lastPrice(), 100000000, "Last price was not set correctly");

        assertEq(pf.lastPayloadTimestamp(), block.timestamp - 1, "Last payload timestamp was not set correctly");

        (, int256 answer,, uint256 updatedAt,) = pf.latestRoundData();

        assertEq(answer, 100000000, "Incorrect answer");
        assertEq(updatedAt, block.timestamp - 1, "Incorrect updatedAt");
    }

    /// @notice U: [RPF-3]: updatePrice reverts on package timestamp not equal to expected payload timestamp
    function test_U_RPF_03_updatePrice_fails_on_at_least_one_package_timestamp_incorrect() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 100000000, uint48((block.timestamp - 1) * 1000), 10, true, false);

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectRevert(DataPackageTimestampIncorrect.selector);

        pf.updatePrice(data);
    }

    /// @notice U: [RPF-4]: updatePrice does nothing if updating in a new block with an old payload
    function test_U_RPF_04_updatePrice_skips_execution_if_updating_with_an_old_payload() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 100000000, uint48((block.timestamp - 1) * 1000), 10, false, false);

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        pf.updatePrice(data);

        vm.roll(block.number + 1);

        expectedPayloadTimestamp = block.timestamp - 1;

        payload =
            _generateRedstonePayload(bytes32("USDC"), 200000000, uint48((block.timestamp - 1) * 1000), 10, false, false);

        data = abi.encode(expectedPayloadTimestamp, payload);

        pf.updatePrice(data);

        assertEq(pf.lastPrice(), 100000000, "Price was wrongly updated");

        assertEq(pf.lastPayloadTimestamp(), block.timestamp - 1);
    }

    /// @notice U: [RPF-5]: updatePrice performs an update for newer payload in the same block
    function test_U_RPF_05_updatePrice_fully_executes_on_new_payload_in_same_block() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 100000000, uint48((block.timestamp - 1) * 1000), 10, false, false);

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        pf.updatePrice(data);

        expectedPayloadTimestamp = block.timestamp + 1;

        payload =
            _generateRedstonePayload(bytes32("USDC"), 200000000, uint48((block.timestamp + 1) * 1000), 10, false, false);

        data = abi.encode(expectedPayloadTimestamp, payload);

        pf.updatePrice(data);

        assertEq(pf.lastPrice(), 200000000, "Price wasn't correctly updated");

        assertEq(pf.lastPayloadTimestamp(), block.timestamp + 1, "Incorrect last payload timestamp");
    }

    /// @notice U: [RPF-6]: updatePrice reverts on at least 1 wrong signer
    function test_U_RPF_06_updatePrice_fails_on_wrong_signer() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 100000000, uint48((block.timestamp - 1) * 1000), 10, false, true);

        address wrongSigner = vm.addr(uint256(keccak256("WRONG")));

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectRevert(abi.encodeWithSelector(SignerNotAuthorised.selector, wrongSigner));

        pf.updatePrice(data);
    }

    /// @notice U: [RPF-7]: updatePrice reverts on less signatures than required
    function test_U_RPF_07_updatePrice_fails_on_insufficient_signatures() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 100000000, uint48((block.timestamp - 1) * 1000), 9, false, false);

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectRevert(abi.encodeWithSelector(InsufficientNumberOfUniqueSigners.selector, 9, 10));

        pf.updatePrice(data);
    }

    /// @notice U: [RPF-8]: updatePrice reverts on zero price
    function test_U_RPF_08_updatePrice_reverts_on_zero_price() public {
        uint256 expectedPayloadTimestamp = block.timestamp - 1;

        bytes memory payload =
            _generateRedstonePayload(bytes32("USDC"), 0, uint48((block.timestamp - 1) * 1000), 10, false, false);

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectRevert(IncorrectPriceException.selector);

        pf.updatePrice(data);
    }

    /// @notice U: [RPF-9]: updatePrice reverts if the payload timestamp is too far from block timestamp
    function test_U_RPF_09_updatePrice_fails_if_payload_timestamp_too_far_from_block() public {
        uint256 expectedPayloadTimestamp = block.timestamp - MAX_DATA_TIMESTAMP_DELAY_SECONDS - 1;

        bytes memory payload = _generateRedstonePayload(
            bytes32("USDC"), 100000000, uint48((expectedPayloadTimestamp) * 1000), 10, false, false
        );

        bytes memory data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectRevert(RedstonePayloadTimestampIncorrect.selector);

        pf.updatePrice(data);

        expectedPayloadTimestamp = block.timestamp + MAX_DATA_TIMESTAMP_AHEAD_SECONDS + 1;

        payload = _generateRedstonePayload(
            bytes32("USDC"), 100000000, uint48((expectedPayloadTimestamp) * 1000), 10, false, false
        );

        data = abi.encode(expectedPayloadTimestamp, payload);

        vm.expectRevert(RedstonePayloadTimestampIncorrect.selector);

        pf.updatePrice(data);
    }
}
