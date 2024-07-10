// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {LibString} from "@solady/utils/LibString.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {IPyth} from "../../interfaces/pyth/IPyth.sol";
import {PythStructs} from "../../interfaces/pyth/PythStructs.sol";

/// @dev Max period that the payload can be backward in time relative to the block
uint256 constant MAX_DATA_TIMESTAMP_DELAY_SECONDS = 10 minutes;

/// @dev Max period that the payload can be forward in time relative to the block
uint256 constant MAX_DATA_TIMESTAMP_AHEAD_SECONDS = 1 minutes;

int256 constant DECIMALS = 10 ** 8;

/// @title Pyth price feed
contract PythPriceFeed is IUpdatablePriceFeed {
    using LibString for string;
    using LibString for bytes32;

    // --------------- //
    // STATE VARIABLES //
    // --------------- //

    uint256 public constant override version = 3_10;
    bytes32 public constant contractType = "PF_PYTH_ORACLE";

    uint8 public constant override decimals = 8;
    bool public constant override skipPriceCheck = false;
    bool public constant override updatable = true;

    /// @notice Token for which the prices are provided
    address public immutable token;

    /// @notice Pyth's ID for the price feed
    bytes32 public immutable priceFeedId;

    /// @notice Address of the Pyth main contract instance
    address public immutable pyth;

    /// @notice The max ratio of p.conf to p.price that would trigger the price feed to revert
    uint256 public immutable maxConfToPriceRatio;

    /// @dev Price feed description ticker
    bytes32 internal _descriptionTicker;

    // ------ //
    // ERRORS //
    // ------ //

    /// @notice Thrown when the timestamp sent with the payload for early stop does not match
    ///         the payload's internal timestamp
    error IncorrectExpectedPublishTimestampException();

    /// @notice Thrown when a retrieved price's publish time is too far ahead in the future
    error PriceTimestampTooFarAheadException();

    /// @notice Thrown when a retrieved price's publish time is too far behind the curent block timestamp
    error PriceTimestampTooFarBehindException();

    /// @notice Thrown when the the ratio between the confidence interval and price is higher than max allowed
    error ConfToPriceRatioTooHighException();

    // ----------- //
    // CONSTRUCTOR //
    // ----------- //

    constructor(
        address _token,
        bytes32 _priceFeedId,
        address _pyth,
        uint256 _maxConfToPriceRatio,
        string memory descriptionTicker
    ) {
        token = _token;
        priceFeedId = _priceFeedId;
        pyth = _pyth;
        maxConfToPriceRatio = _maxConfToPriceRatio;
        _descriptionTicker = descriptionTicker.toSmallString();
    }

    // --------- //
    // FUNCTIONS //
    // --------- //

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(_descriptionTicker.fromSmallString(), " Pyth price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() external view returns (bytes memory) {
        return abi.encode(token, priceFeedId, pyth, maxConfToPriceRatio);
    }

    /// @notice Returns the USD price of the token with 8 decimals and the last update timestamp
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        PythStructs.Price memory priceData = IPyth(pyth).getPriceUnsafe(priceFeedId);

        if (uint256(priceData.conf) * PERCENTAGE_FACTOR > uint256(int256(priceData.price)) * maxConfToPriceRatio) {
            revert ConfToPriceRatioTooHighException();
        }

        _validatePublishTimestamp(priceData.publishTime);

        int256 price = _getDecimalAdjustedPrice(priceData);

        return (0, price, 0, priceData.publishTime, 0);
    }

    /// @notice Passes a Pyth payload to the Pyth oracle to update the price
    /// @param data A data blob with with 2 parts:
    ///        - Publish time reported by Pyth API - must be equal to publish time after update
    ///        - Pyth payload from Hermes
    function updatePrice(bytes calldata data) external override {
        (uint256 expectedPublishTimestamp, bytes[] memory updateData) = abi.decode(data, (uint256, bytes[]));

        uint256 lastPublishTimestamp = IPyth(pyth).latestPriceInfoPublishTime(priceFeedId);

        // We want to minimize price update execution, in case, e.g., when several users submit
        // the same price update in a short span of time. So only updates with a larger payload timestamp than last recorded
        // are sent to Pyth. While Pyth technically performs an early stop by not writing a new price for outdated payloads,
        // it still performs payload validation before that, which is expensive
        if (expectedPublishTimestamp <= lastPublishTimestamp) return;
        _validatePublishTimestamp(expectedPublishTimestamp);

        uint256 fee = IPyth(pyth).getUpdateFee(updateData);
        IPyth(pyth).updatePriceFeeds{value: fee}(updateData);

        PythStructs.Price memory priceData = IPyth(pyth).getPriceUnsafe(priceFeedId);

        if (priceData.publishTime != expectedPublishTimestamp) revert IncorrectExpectedPublishTimestampException();
        if (priceData.price == 0) revert IncorrectPriceException();

        emit UpdatePrice(uint64(priceData.price));
    }

    /// @dev Returns price adjusted to 8 decimals (if Pyth returns different precision)
    function _getDecimalAdjustedPrice(PythStructs.Price memory priceData) internal pure returns (int256) {
        int256 price = int256(priceData.price);

        if (price == 0) revert IncorrectPriceException();

        if (priceData.expo != -8) {
            int256 pythDecimals = int256(uint256(10) ** uint32(-priceData.expo));
            price = price * DECIMALS / pythDecimals;
        }

        return price;
    }

    /// @dev Validates that the timestamp is not too far from the current block's
    /// @param publishTimestamp The payload's publish timestamp
    function _validatePublishTimestamp(uint256 publishTimestamp) internal view {
        if ((block.timestamp < publishTimestamp)) {
            if ((publishTimestamp - block.timestamp) > MAX_DATA_TIMESTAMP_AHEAD_SECONDS) {
                revert PriceTimestampTooFarAheadException();
            }
        } else if ((block.timestamp - publishTimestamp) > MAX_DATA_TIMESTAMP_DELAY_SECONDS) {
            revert PriceTimestampTooFarBehindException();
        }
    }

    /// @dev Receive is defined so that ETH can be precharged on the price feed to cover future Pyth feeds
    receive() external payable {}
}
