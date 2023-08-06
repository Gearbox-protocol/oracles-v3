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
///         It is assumed that the price of an LP token is the product of its exchange rate and some aggregate function
///         of underlying tokens prices. This contract simplifies creation of such price feeds and provides standard
///         validation of the LP token exchange rate that protects against price manipulation.
abstract contract LPPriceFeed is ILPPriceFeed, AbstractPriceFeed, ACLNonReentrantTrait {
    /// @notice LP token for which the prices are computed
    address public immutable override lpToken;

    /// @notice LP contract (can be different from LP token)
    address public immutable override lpContract;

    /// @notice Lower bound for the LP token exchange rate
    uint256 public override lowerBound;

    /// @notice Window size in bps, used to compute upper bound given lower bound
    uint256 public constant override delta = 2_00;

    /// @notice Constructor
    /// @param _addressProvider Address provider contract address
    /// @param _lpToken  LP token for which the prices are computed
    /// @param _lpContract LP contract (can be different from LP token)
    constructor(address _addressProvider, address _lpToken, address _lpContract)
        ACLNonReentrantTrait(_addressProvider)
        nonZeroAddress(_lpToken)
        nonZeroAddress(_lpContract)
    {
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

        uint256 ub = _upperBound(lb);
        if (exchangeRate > ub) exchangeRate = ub;

        (answer, updatedAt) = getAggregatePrice();
        answer = int256((exchangeRate * uint256(answer)) / getScale());
        return (0, answer, 0, updatedAt, 0);
    }

    /// @notice Upper bound for the LP token exchange rate
    function upperBound() external view returns (uint256) {
        return _upperBound(lowerBound);
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

    /// @dev Computes upper bound as `lowerBound * (1 + delta)`
    function _upperBound(uint256 lb) internal pure returns (uint256) {
        return (lb * (PERCENTAGE_FACTOR + delta)) / PERCENTAGE_FACTOR;
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets new lower and upper bounds for the LP token exchange rate
    /// @param newLowerBound New lower bound value
    /// @dev New upper bound value is computed as `newLowerBound * (1 + delta)`
    function setLimiter(uint256 newLowerBound) external override controllerOnly {
        uint256 exchangeRate = getLPExchangeRate();
        if (newLowerBound == 0 || exchangeRate < newLowerBound || exchangeRate > _upperBound(newLowerBound)) {
            revert IncorrectLimitsException();
        }
        lowerBound = newLowerBound;
        emit SetBounds(newLowerBound, _upperBound(newLowerBound));
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
