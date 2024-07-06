// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeed.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/// @dev Max period that the payload can be backward in time relative to the block
uint256 constant MAX_DATA_TIMESTAMP_DELAY_SECONDS = 10 minutes;

/// @dev Max period that the payload can be forward in time relative to the block
uint256 constant MAX_DATA_TIMESTAMP_AHEAD_SECONDS = 1 minutes;

uint256 constant DECIMALS = 10 ** 8;

interface IPythExtended {
    function latestPriceInfoPublishTime(bytes32 priceFeedId) external view returns (uint64);
}

interface IPythPriceFeedExceptions {
    /// @notice Thrown when the timestamp sent with the payload for early stop does not match
    ///         the payload's internal timestamp
    error IncorrectExpectedPublishTimestamp();
}

/// @title Pyth price feed
contract PythPriceFeed is IUpdatablePriceFeed, IPythPriceFeedExceptions {
    using SafeCast for uint256;

    PriceFeedType public constant override priceFeedType = PriceFeedType.PYTH_ORACLE;

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

    /// @dev Price feed description
    string public description;

    constructor(address _token, bytes32 _priceFeedId, address _pyth, string memory _descriptionTicker) {
        token = _token;
        priceFeedId = _priceFeedId;
        pyth = _pyth;
        description = string.concat(_descriptionTicker, " Pyth price feed");
    }

    /// @notice Returns the USD price of the token with 8 decimals and the last update timestamp
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        PythStructs.Price memory priceData = IPyth(pyth).getPriceUnsafe(priceFeedId);

        int256 price = _getDecimalAdjustedPrice(priceData);

        return (0, price, 0, priceData.publishTime, 0);
    }

    /// @notice Passes a Pyth payload to the Pyth oracle to update the price
    /// @param data A data blob with with 2 parts:
    ///        - Publish time reported by Pyth API - must be equal to publish time after update
    ///        - Pyth payload from Hermes
    function updatePrice(bytes calldata data) external override {
        (uint256 expectedPublishTimestamp, bytes[] memory updateData) = abi.decode(data, (uint256, bytes[]));

        uint256 lastPublishTimestamp = uint256(IPythExtended(pyth).latestPriceInfoPublishTime(priceFeedId));

        // We want to minimize price update execution, in case, e.g., when several users submit
        // the same price update in a short span of time. So only updates with a larger payload timestamp than last recorded
        // are sent to Pyth. While Pyth technically performs an early stop by not writing a new price for outdated payloads,
        // it still performs payload validation before that, which is expensive
        if (expectedPublishTimestamp <= lastPublishTimestamp) return;
        _validateExpectedPublishTimestamp(expectedPublishTimestamp);

        uint256 fee = IPyth(pyth).getUpdateFee(updateData);
        IPyth(pyth).updatePriceFeeds{value: fee}(updateData);

        PythStructs.Price memory priceData = IPyth(pyth).getPriceUnsafe(priceFeedId);

        if (priceData.publishTime != expectedPublishTimestamp) revert IncorrectExpectedPublishTimestamp();
        if (priceData.price == 0) revert IncorrectPriceException();
    }

    /// @dev Returns price adjusted to 8 decimals (if Pyth returns different precision)
    function _getDecimalAdjustedPrice(PythStructs.Price memory priceData) internal pure returns (int256) {
        int256 price = int256(priceData.price);

        if (priceData.expo != -8) {
            if (priceData.expo >= 0) {
                price = price * int256(10 ** (uint256(int256(priceData.expo)) + 8));
            } else {
                price = price * int256(DECIMALS) / int256((10 ** uint256(int256(-priceData.expo))));
            }
        }

        return price;
    }

    /// @dev Validates that the expected payload timestamp is not too far from the current block's
    /// @param expectedPublishTimestamp Expected timestamp after the current price update
    function _validateExpectedPublishTimestamp(uint256 expectedPublishTimestamp) internal view {
        if ((block.timestamp < expectedPublishTimestamp)) {
            if ((expectedPublishTimestamp - block.timestamp) > MAX_DATA_TIMESTAMP_AHEAD_SECONDS) {
                revert IncorrectExpectedPublishTimestamp();
            }
        } else if ((block.timestamp - expectedPublishTimestamp) > MAX_DATA_TIMESTAMP_DELAY_SECONDS) {
            revert IncorrectExpectedPublishTimestamp();
        }
    }

    /// @dev Receive is defined so that ETH can be precharged on the price feed to cover future Pyth feeds
    receive() external payable {}
}
