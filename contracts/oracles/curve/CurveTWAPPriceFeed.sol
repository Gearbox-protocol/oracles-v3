// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Curve TWAP price feed
/// @notice Computes price of coin 1 in a Curve pool in terms of units of coin 0, based on the pool's TWAP, which is then
///         multiplied by the price of coin 0.
contract CurveTWAPPriceFeed is IPriceFeed, PriceFeedValidationTrait, SanityCheckTrait {
    using Address for address;

    /// @notice Thrown when the curve oracle value is out of bounds
    error CurveOracleOutOfBoundsException();

    /// @notice Thrown when the upper bound is less than the lower bound passed in constructor
    error UpperBoundTooLowException();

    /// @notice Contract version
    uint256 public constant override version = 3_10;

    /// @notice Contract type
    bytes32 public constant override contractType = "PRICE_FEED::CURVE_USD";

    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true;

    /// @notice token token address
    address public immutable token;

    /// @notice Curve pool address
    address public immutable pool;

    /// @notice Coin 0 price feed address
    address public immutable priceFeed;

    /// @notice Staleness period for the coin 0 price feed
    uint32 public immutable stalenessPeriod;

    /// @notice Flag indicating if price feed checks can be skipped
    bool public immutable skipCheck;

    /// @notice Lower bound for the exchange rate
    uint256 public immutable lowerBound;

    /// @notice Upper bound for the exchange rate
    uint256 public immutable upperBound;

    /// @notice Price feed description
    string public description;

    /// @notice Constructor
    /// @param _lowerBound Lower bound for the pool exchange rate
    /// @param _upperBound Upper bound for the pool exchange rate (must be greater than lower bound)
    /// @param _token Address of the coin 1 in the pool
    /// @param _pool Address of the curve pool
    /// @param _priceFeed Address of the coin 0 price feed
    /// @param _stalenessPeriod Staleness period for the coin 0 price feed
    constructor(
        uint256 _lowerBound,
        uint256 _upperBound,
        address _token,
        address _pool,
        address _priceFeed,
        uint32 _stalenessPeriod
    ) nonZeroAddress(_token) nonZeroAddress(_pool) nonZeroAddress(_priceFeed) {
        if (_upperBound < _lowerBound) revert UpperBoundTooLowException();

        token = _token;
        pool = _pool;
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        skipCheck = _validatePriceFeedMetadata(_priceFeed, _stalenessPeriod);
        lowerBound = _lowerBound;
        upperBound = _upperBound;

        string memory tokenSymbol = IERC20Metadata(_token).symbol();
        description = string.concat(tokenSymbol, " / USD Curve TWAP price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() external view override returns (bytes memory) {
        return abi.encode(token, pool, priceFeed, lowerBound, upperBound);
    }

    /// @notice Returns USD price of the token token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        uint256 exchangeRate = ICurvePool(pool).price_oracle();

        if (exchangeRate < lowerBound) revert CurveOracleOutOfBoundsException();
        if (exchangeRate > upperBound) exchangeRate = upperBound;

        int256 underlyingPrice = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck);

        answer = int256((exchangeRate * uint256(underlyingPrice)) / WAD);

        return (0, answer, 0, 0, 0);
    }
}
