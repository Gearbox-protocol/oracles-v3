// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ILPPriceFeed} from "../interfaces/ILPPriceFeed.sol";
import {AbstractPriceFeed} from "./AbstractPriceFeed.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLNonReentrantTrait.sol";

// EXCEPTIONS
import {
    ValueOutOfRangeException,
    IncorrectLimitsException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title LP price feed
/// @notice Abstract contract for LP token price feeds.
///         Typically, the price of an LP token is some function of its exchange rate (or virtual price) and
///         prices of underlying tokens. This contract simplifies creation of such price feeds and provides
///         standardized validation of the LP token exchange rate that protects against price manipulation.
abstract contract LPPriceFeed is ILPPriceFeed, AbstractPriceFeed, ACLNonReentrantTrait {
    /// @notice LP token for which the prices are computed
    address public immutable override lpToken;

    /// @notice Lower bound for the LP token exchange rate
    uint256 public lowerBound;

    /// @notice Window size in bps, used to compute upper bound given lower bound
    uint256 public immutable delta;

    /// @notice Constructor
    /// @param addressProvider Address provider contract address
    /// @param _lpToken  LP token for which the prices are computed
    /// @param _delta Window size in bps
    constructor(address addressProvider, address _lpToken, uint256 _delta)
        ACLNonReentrantTrait(addressProvider)
        nonZeroAddress(_lpToken)
    {
        lpToken = _lpToken;
        delta = _delta; // F:[LPF-1]
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string(abi.encodePacked(ERC20(lpToken).symbol(), " / USD price feed"));
    }

    /// @notice Upper bound for the LP token exchange rate
    function upperBound() external view returns (uint256) {
        return _upperBound(lowerBound); // F:[LPF-5]
    }

    /// @dev Returns upper-bounded LP token exhcange rate and its scale, reverts if rate falls below the lower bound
    /// @dev When computing LP token price, this MUST be used to get the exchange rate
    function _getValidatedLPExchangeRate() internal view returns (uint256 exchangeRate) {
        exchangeRate = getLPExchangeRate();

        uint256 lb = lowerBound;
        if (exchangeRate < lb) revert ValueOutOfRangeException();

        uint256 ub = _upperBound(lb);
        return exchangeRate > ub ? ub : exchangeRate;
    }

    /// @dev Returns LP token exchange rate, must be implemented by derived price feeds
    function getLPExchangeRate() public view virtual returns (uint256 exchangeRate);

    /// @dev Computes upper bound as `lowerBound * (1 + delta)`
    function _upperBound(uint256 lb) internal view returns (uint256) {
        return (lb * (PERCENTAGE_FACTOR + delta)) / PERCENTAGE_FACTOR; // F:[LPF-5]
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets new lower and upper bounds for the LP token exchange rate
    /// @param newLowerBound New lower bound value
    /// @dev New upper bound value is computed as `newLowerBound * (1 + delta)`
    function setLimiter(uint256 newLowerBound)
        external
        override
        controllerOnly // F:[LPF-4]
    {
        uint256 exchangeRate = getLPExchangeRate();
        if (newLowerBound == 0 || exchangeRate < newLowerBound || exchangeRate > _upperBound(newLowerBound)) {
            revert IncorrectLimitsException(); // F:[LPF-4]
        }
        lowerBound = newLowerBound; // F:[LPF-5]
        emit SetBounds(newLowerBound, _upperBound(newLowerBound)); // F:[LPF-5]
    }

    /// @dev Inititalizes bounds such that lower bound is the current LP token exhcange rate
    /// @dev Derived price feeds MUST call this in the constructor after initializing all the
    ///      state variables needed for exchange rate calculation
    function _initLimiter() internal {
        uint256 newLowerBound = getLPExchangeRate();
        lowerBound = newLowerBound;
        emit SetBounds(newLowerBound, _upperBound(newLowerBound));
    }
}
