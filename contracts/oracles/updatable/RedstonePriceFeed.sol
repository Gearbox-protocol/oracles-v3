// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {RedstoneConsumerNumericBase} from
    "@redstone-finance/evm-connector/contracts/core/RedstoneConsumerNumericBase.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

/// @dev Max period that the payload can be backward in time relative to the block
uint256 constant MAX_DATA_TIMESTAMP_DELAY_SECONDS = 10 minutes;

/// @dev Max period that the payload can be forward in time relative to the block
uint256 constant MAX_DATA_TIMESTAMP_AHEAD_SECONDS = 1 minutes;

/// @dev Max number of authorized signers
uint256 constant MAX_SIGNERS = 10;

interface IRedstonePriceFeedExceptions {
    /// @notice Thrown when trying to construct a price feed with incorrect signers threshold
    error IncorrectSignersThresholdException();

    /// @notice Thrown when the provided set of signers is smaller than the threshold
    error NotEnoughSignersException();

    /// @notice Thrown when the provided set of signers contains duplicates
    error DuplicateSignersException();

    /// @notice Thrown when attempting to push an update with the payload that is older than the last
    ///         update payload, or too far from the current block timestamp
    error RedstonePayloadTimestampIncorrect();

    /// @notice Thrown when data package timestamp is not equal to expected payload timestamp
    error DataPackageTimestampIncorrect();
}

/// @title Redstone price feed
contract RedstonePriceFeed is IUpdatablePriceFeed, IRedstonePriceFeedExceptions, RedstoneConsumerNumericBase {
    using SafeCast for uint256;

    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_REDSTONE_ORACLE";
    uint8 public constant override decimals = 8;
    bool public constant override skipPriceCheck = false;
    bool public constant override updatable = true;

    /// @notice Token for which the prices are provided
    address public immutable token;

    /// @notice ID of the asset in Redstone's payload
    bytes32 public immutable dataFeedId;

    address public immutable signerAddress0;
    address public immutable signerAddress1;
    address public immutable signerAddress2;
    address public immutable signerAddress3;
    address public immutable signerAddress4;
    address public immutable signerAddress5;
    address public immutable signerAddress6;
    address public immutable signerAddress7;
    address public immutable signerAddress8;
    address public immutable signerAddress9;

    /// @dev Minimal number of unique signatures from authorized signers required to validate a payload
    uint8 internal immutable _signersThreshold;

    /// @notice The last stored price value
    uint128 public lastPrice;

    /// @notice The timestamp of the last update's payload
    uint40 public lastPayloadTimestamp;

    constructor(address _token, bytes32 _dataFeedId, address[MAX_SIGNERS] memory _signers, uint8 signersThreshold) {
        if (signersThreshold == 0 || signersThreshold > MAX_SIGNERS) revert IncorrectSignersThresholdException();
        unchecked {
            uint256 numSigners;
            for (uint256 i; i < MAX_SIGNERS; ++i) {
                if (_signers[i] == address(0)) continue;
                for (uint256 j = i + 1; j < MAX_SIGNERS; ++j) {
                    if (_signers[j] == _signers[i]) revert DuplicateSignersException();
                }
                ++numSigners;
            }
            if (numSigners < signersThreshold) revert NotEnoughSignersException();
        }

        token = _token;
        dataFeedId = _dataFeedId; // U:[RPF-1]

        signerAddress0 = _signers[0];
        signerAddress1 = _signers[1];
        signerAddress2 = _signers[2];
        signerAddress3 = _signers[3];
        signerAddress4 = _signers[4];
        signerAddress5 = _signers[5];
        signerAddress6 = _signers[6];
        signerAddress7 = _signers[7];
        signerAddress8 = _signers[8];
        signerAddress9 = _signers[9];

        _signersThreshold = signersThreshold; // U:[RPF-1]
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string(abi.encodePacked(ERC20(token).symbol(), " / USD Redstone price feed")); // U:[RPF-1]
    }

    /// @notice Returns the USD price of the token with 8 decimals and the last update timestamp
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, int256(uint256(lastPrice)), 0, lastPayloadTimestamp, 0); // U:[RPF-2]
    }

    /// @notice Saves validated price retrieved from the passed Redstone payload
    /// @param data A data blob with with 2 parts:
    ///        - A timestamp expected to be in all Redstone data packages
    ///        - Redstone payload with price update
    function updatePrice(bytes calldata data) external override {
        (uint256 expectedPayloadTimestamp,) = abi.decode(data, (uint256, bytes));

        // We want to minimize price update execution, in case, e.g., when several users submit
        // the same price update in a short span of time. So only updates with a larger payload timestamp
        // are fully validated and applied
        if (expectedPayloadTimestamp <= lastPayloadTimestamp) return; // U:[RPF-4]

        // We validate and set the payload timestamp here. Data packages' timestamps being equal
        // to the expected timestamp is checked in `validateTimestamp()`, which is called
        // from inside `getOracleNumericValueFromTxMsg`
        _validateExpectedPayloadTimestamp(expectedPayloadTimestamp);
        lastPayloadTimestamp = uint40(expectedPayloadTimestamp); // U:[RPF-2,5]

        uint256 priceValue = getOracleNumericValueFromTxMsg(dataFeedId); // U:[RPF-7]

        if (priceValue == 0) revert IncorrectPriceException(); // U:[RPF-8]

        if (priceValue != lastPrice) {
            lastPrice = priceValue.toUint128(); // U:[RPF-2,5]
            emit UpdatePrice(priceValue); // U:[RPF-2,5]
        }
    }

    /// @notice Returns the number of unique signatures required to validate a payload
    function getUniqueSignersThreshold() public view virtual override returns (uint8) {
        return _signersThreshold;
    }

    /// @notice Returns the index of the provided signer or reverts if the address is not a signer
    function getAuthorisedSignerIndex(address signerAddress) public view virtual override returns (uint8) {
        if (signerAddress == address(0)) revert SignerNotAuthorised(signerAddress);

        if (signerAddress == signerAddress0) return 0;
        if (signerAddress == signerAddress1) return 1;
        if (signerAddress == signerAddress2) return 2;
        if (signerAddress == signerAddress3) return 3;
        if (signerAddress == signerAddress4) return 4;
        if (signerAddress == signerAddress5) return 5;
        if (signerAddress == signerAddress6) return 6;
        if (signerAddress == signerAddress7) return 7;
        if (signerAddress == signerAddress8) return 8;
        if (signerAddress == signerAddress9) return 9;

        revert SignerNotAuthorised(signerAddress); // U:[RPF-6]
    }

    /// @notice Validates that a timestamp in a data package is valid
    /// @dev Sanity checks on the timestamp are performed earlier in the update,
    ///      when the lastPayloadTimestamp is being set
    /// @param receivedTimestampMilliseconds Timestamp in the data package, in milliseconds
    function validateTimestamp(uint256 receivedTimestampMilliseconds) public view override {
        uint256 receivedTimestampSeconds = receivedTimestampMilliseconds / 1000;

        if (receivedTimestampSeconds != lastPayloadTimestamp) {
            revert DataPackageTimestampIncorrect(); // U:[RPF-3]
        }
    }

    /// @dev Validates that the expected payload timestamp is not older than the last payload's,
    ///      and not too far from the current block's
    /// @param expectedPayloadTimestamp Timestamp expected to be in all of the incoming payload's packages
    function _validateExpectedPayloadTimestamp(uint256 expectedPayloadTimestamp) internal view {
        if ((block.timestamp < expectedPayloadTimestamp)) {
            if ((expectedPayloadTimestamp - block.timestamp) > MAX_DATA_TIMESTAMP_AHEAD_SECONDS) {
                revert RedstonePayloadTimestampIncorrect(); // U:[RPF-9]
            }
        } else if ((block.timestamp - expectedPayloadTimestamp) > MAX_DATA_TIMESTAMP_DELAY_SECONDS) {
            revert RedstonePayloadTimestampIncorrect(); // U:[RPF-9]
        }
    }
}
