// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {ILPPriceFeed} from "../interfaces/ILPPriceFeed.sol";
import {AbstractPriceFeed} from "./AbstractPriceFeed.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLNonReentrantTrait.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {
    IAddressProviderV3, AP_PRICE_ORACLE
} from "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";

// EXCEPTIONS
import {
    ValueOutOfRangeException,
    IncorrectLimitsException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @dev Window size in bps, used to compute upper bound given lower bound
uint256 constant WINDOW_SIZE = 200;

/// @dev Buffer size in bps, used to compute new lower bound given current exchange rate
uint256 constant BUFFER_SIZE = 20;

/// @title LP price feed
/// @notice Abstract contract for LP token price feeds.
///         It is assumed that the price of an LP token is the product of its exchange rate and some aggregate function
///         of underlying tokens prices. This contract simplifies creation of such price feeds and provides standard
///         validation of the LP token exchange rate that protects against price manipulation.
abstract contract LPPriceFeed is ILPPriceFeed, AbstractPriceFeed, ACLNonReentrantTrait {
    /// @notice Address provider contract
    address public immutable override addressProvider;

    /// @notice LP token for which the prices are computed
    address public immutable override lpToken;

    /// @notice LP contract (can be different from LP token)
    address public immutable override lpContract;

    /// @notice Lower bound for the LP token exchange rate
    uint256 public override lowerBound;

    /// @notice Whether permissionless bounds update is allowed
    bool public override updateBoundsAllowed;

    /// @notice Constructor
    /// @param _addressProvider Address provider contract address
    /// @param _lpToken  LP token for which the prices are computed
    /// @param _lpContract LP contract (can be different from LP token)
    constructor(address _addressProvider, address _lpToken, address _lpContract)
        ACLNonReentrantTrait(_addressProvider)
        nonZeroAddress(_lpToken)
        nonZeroAddress(_lpContract)
    {
        addressProvider = _addressProvider;
        lpToken = _lpToken;
        lpContract = _lpContract;
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string(abi.encodePacked(ERC20(lpToken).symbol(), " / USD price feed"));
    }

    /// @notice Returns USD price of the LP token with 8 decimals
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        uint256 exchangeRate = getLPExchangeRate();
        uint256 lb = lowerBound;
        if (exchangeRate < lb) revert ValueOutOfRangeException();

        uint256 ub = _calcUpperBound(lb);
        if (exchangeRate > ub) exchangeRate = ub;

        (answer, updatedAt) = getAggregatePrice();
        answer = int256((exchangeRate * uint256(answer)) / getScale());
        return (0, answer, 0, updatedAt, 0);
    }

    /// @notice Upper bound for the LP token exchange rate
    function upperBound() external view returns (uint256) {
        return _calcUpperBound(lowerBound);
    }

    /// @notice Returns aggregate price of underlying tokens
    /// @dev Must be implemented by derived price feeds
    function getAggregatePrice() public view virtual override returns (int256 answer, uint256 updatedAt);

    /// @notice Returns LP token exchange rate
    /// @dev Must be implemented by derived price feeds
    function getLPExchangeRate() public view virtual override returns (uint256 exchangeRate);

    /// @notice Returns LP token exchange rate scale
    /// @dev Must be implemented by derived price feeds
    function getScale() public view virtual override returns (uint256 scale);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Allows or forbids permissionless bounds update
    function setUpdateBoundsAllowed(bool allowed) external override configuratorOnly {
        if (updateBoundsAllowed == allowed) return;
        updateBoundsAllowed = allowed;
        emit SetUpdateBoundsAllowed(allowed);
    }

    /// @notice Sets new lower and upper bounds for the LP token exchange rate
    /// @param newLowerBound New lower bound value
    function setLimiter(uint256 newLowerBound) external override controllerOnly {
        _setLimiter(newLowerBound, getLPExchangeRate());
    }

    /// @notice Permissionlessly updates LP token's exchange rate bounds using answer from the reserve price feed.
    ///         Lower bound is set to the induced reserve exchange rate (with small buffer for downside movement).
    /// @param updatePrice If true, update the reserve price feed prior to querying its answer
    /// @param data Data to update the reserve price feed with
    function updateBounds(bool updatePrice, bytes calldata data) external override {
        if (!updateBoundsAllowed) return;

        address priceOracle = IAddressProviderV3(addressProvider).getAddressOrRevert(AP_PRICE_ORACLE, 3_00);
        address reserveFeed = IPriceOracleV3(priceOracle).priceFeedsRaw({token: lpToken, reserve: true});
        if (updatePrice) IUpdatablePriceFeed(reserveFeed).updatePrice(data);

        (, int256 reserveAnswer,,,) = IPriceFeed(reserveFeed).latestRoundData();
        (int256 price,) = getAggregatePrice();
        uint256 reserveExchangeRate = uint256(reserveAnswer * int256(getScale()) / price);

        _setLimiter(_calcLowerBound(reserveExchangeRate), getLPExchangeRate());
    }

    /// @dev Sets lower bound to the current LP token exhcange rate (with small buffer for downside movement)
    /// @dev Derived price feeds MUST call this in the constructor after initializing all the state variables
    ///      needed for exchange rate calculation
    function _initLimiter() internal {
        uint256 exchangeRate = getLPExchangeRate();
        _setLimiter(_calcLowerBound(exchangeRate), exchangeRate);
    }

    /// @dev `setLimiter` implementation: sets new bounds, ensures that current value is within them, emits event
    function _setLimiter(uint256 lower, uint256 current) internal {
        uint256 upper = _calcUpperBound(lower);
        if (lower == 0 || current < lower || current > upper) revert IncorrectLimitsException();
        lowerBound = lower;
        emit SetBounds(lower, upper);
    }

    /// @dev Computes upper bound as `_lowerBound * (1 + WINDOW_SIZE)`
    function _calcUpperBound(uint256 _lowerBound) internal pure returns (uint256) {
        return _lowerBound * (PERCENTAGE_FACTOR + WINDOW_SIZE) / PERCENTAGE_FACTOR;
    }

    /// @dev Computes lower bound as `exchangeRate * (1 - BUFFER_SIZE)`
    function _calcLowerBound(uint256 exchangeRate) internal pure returns (uint256) {
        return exchangeRate * (PERCENTAGE_FACTOR - BUFFER_SIZE) / PERCENTAGE_FACTOR;
    }
}
