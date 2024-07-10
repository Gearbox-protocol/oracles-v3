// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ILPPriceFeed} from "../interfaces/ILPPriceFeed.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {ControlledTrait} from "@gearbox-protocol/core-v3/contracts/traits/ControlledTrait.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

/// @dev Window size in bps, used to compute upper bound given lower bound
uint256 constant WINDOW_SIZE = 200;

/// @dev Buffer size in bps, used to compute new lower bound given current exchange rate
uint256 constant BUFFER_SIZE = 100;

/// @dev Minimum interval between two permissionless bounds updates
uint256 constant UPDATE_BOUNDS_COOLDOWN = 1 days;

/// @title LP price feed
/// @notice Abstract contract for LP token price feeds.
///         It is assumed that the price of an LP token is the product of its exchange rate and some aggregate function
///         of underlying tokens prices. This contract simplifies creation of such price feeds and provides standard
///         validation of the LP token exchange rate that protects against price manipulation.
abstract contract LPPriceFeed is ILPPriceFeed, ControlledTrait, SanityCheckTrait, PriceFeedValidationTrait {
    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8; // U:[LPPF-2]

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true; // U:[LPPF-2]

    /// @notice LP token for which the prices are computed
    address public immutable override lpToken;

    /// @notice LP contract (can be different from LP token)
    address public immutable override lpContract;

    /// @notice Lower bound for the LP token exchange rate
    uint256 public override lowerBound;

    /// @notice Constructor
    /// @param _acl Address of the ACL contract
    /// @param _lpToken  LP token for which the prices are computed
    /// @param _lpContract LP contract (can be different from LP token)
    /// @dev Derived price feeds must call `_setLimiter` in their constructor after
    ///      initializing all state variables needed for exchange rate calculation
    constructor(address _acl, address _lpToken, address _lpContract)
        ControlledTrait(_acl) // U:[LPPF-1]
        nonZeroAddress(_lpToken) // U:[LPPF-1]
        nonZeroAddress(_lpContract) // U:[LPPF-1]
    {
        lpToken = _lpToken; // U:[LPPF-1]
        lpContract = _lpContract; // U:[LPPF-1]
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string(abi.encodePacked(ERC20(lpToken).symbol(), " / USD price feed")); // U:[LPPF-2]
    }

    /// @notice Returns USD price of the LP token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        uint256 exchangeRate = getLPExchangeRate();
        uint256 lb = lowerBound;
        if (exchangeRate < lb) revert ExchangeRateOutOfBoundsException(); // U:[LPPF-3]

        uint256 ub = _calcUpperBound(lb);
        if (exchangeRate > ub) exchangeRate = ub; // U:[LPPF-3]

        answer = int256((exchangeRate * uint256(getAggregatePrice())) / getScale()); // U:[LPPF-3]
        return (0, answer, 0, 0, 0);
    }

    /// @notice Upper bound for the LP token exchange rate
    function upperBound() external view returns (uint256) {
        return _calcUpperBound(lowerBound); // U:[LPPF-4]
    }

    /// @notice Returns aggregate price of underlying tokens with 8 decimals
    /// @dev Must be implemented by derived price feeds
    function getAggregatePrice() public view virtual override returns (int256 answer);

    /// @notice Returns LP token exchange rate
    /// @dev Must be implemented by derived price feeds
    function getLPExchangeRate() public view virtual override returns (uint256 exchangeRate);

    /// @notice Returns LP token exchange rate scale
    /// @dev Must be implemented by derived price feeds
    function getScale() public view virtual override returns (uint256 scale);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets new lower and upper bounds for the LP token exchange rate
    /// @param newLowerBound New lower bound value
    function setLimiter(uint256 newLowerBound)
        external
        override
        controllerOrConfiguratorOnly // U:[LPPF-6]
    {
        _setLimiter(newLowerBound); // U:[LPPF-6]
    }

    // --------- //
    // INTERNALS //
    // --------- //

    /// @dev `setLimiter` implementation: sets new bounds, ensures that current value is within them, emits event
    function _setLimiter(uint256 lower) internal {
        if (lower == 0) revert LowerBoundCantBeZeroException(); // U:[LPPF-6]
        uint256 upper = _ensureValueInBounds(getLPExchangeRate(), lower); // U:[LPPF-6]
        lowerBound = lower; // U:[LPPF-6]
        emit SetBounds(lower, upper); // U:[LPPF-6]
    }

    /// @dev Computes upper bound as `_lowerBound * (1 + WINDOW_SIZE)`
    function _calcUpperBound(uint256 _lowerBound) internal pure returns (uint256) {
        return _lowerBound * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR; // U:[LPPF-4]
    }

    /// @dev Computes lower bound as `exchangeRate * (1 - BUFFER_SIZE)`
    function _calcLowerBound(uint256 exchangeRate) internal pure returns (uint256) {
        return exchangeRate * (PERCENTAGE_FACTOR - BUFFER_SIZE) / PERCENTAGE_FACTOR; // U:[LPPF-6]
    }

    /// @dev Ensures that value is in bounds, returns upper bound computed from lower bound
    function _ensureValueInBounds(uint256 value, uint256 lower) internal pure returns (uint256 upper) {
        if (value < lower) revert ExchangeRateOutOfBoundsException();
        upper = _calcUpperBound(lower);
        if (value > upper) revert ExchangeRateOutOfBoundsException();
    }
}
