// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {ILPPriceFeed} from "../interfaces/ILPPriceFeed.sol";
import {AbstractPriceFeed} from "./AbstractPriceFeed.sol";
import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLNonReentrantTrait.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// EXCEPTIONS
import {
    NotImplementedException,
    ValueOutOfRangeException,
    IncorrectLimitsException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Abstract PriceFeed for an LP token
/// @notice For most pools/vaults, the LP token price depends on Chainlink prices of pool assets and the pool's
/// internal exchange rate.
abstract contract LPPriceFeed is ILPPriceFeed, AbstractPriceFeed, ACLNonReentrantTrait {
    /// @dev The lower bound for the contract's token-to-underlying exchange rate.
    /// @notice Used to protect against LP token / share price manipulation.
    uint256 public lowerBound;

    /// @dev Window size in PERCENTAGE format. Upper bound = lowerBound * (1 + delta)
    uint256 public immutable delta;

    /// @dev Decimals of the returned result.
    uint8 public constant override decimals = 8;

    /// @dev Price feed description
    string public override description;

    /// @dev Constructor
    /// @param addressProvider Address of address provier which is use for getting ACL
    /// @param _delta Pre-defined window in PERCENTAGE FORMAT which is allowed for SC value
    /// @param _description Price feed description
    constructor(address addressProvider, uint256 _delta, string memory _description)
        ACLNonReentrantTrait(addressProvider)
    {
        description = _description; // F:[LPF-1]
        delta = _delta; // F:[LPF-1]
    }

    /// @dev Checks that value is in range [lowerBound; upperBound],
    /// Reverts if below lowerBound and returns min(value, upperBound)
    function _getValidatedContractValue() internal view returns (uint256) {
        return _checkAndUpperBoundValue(_getContractValue());
    }

    function _checkAndUpperBoundValue(uint256 value) internal view returns (uint256) {
        uint256 lb = lowerBound;
        if (value < lb) revert ValueOutOfRangeException(); // F:[LPF-3]

        uint256 uBound = _upperBound(lb);

        return (value > uBound) ? uBound : value;
    }

    /// @dev Updates the bounds for the exchange rate value
    /// @param _lowerBound The new lower bound (the upper bound is computed dynamically)
    ///                    from the lower bound
    function setLimiter(uint256 _lowerBound)
        external
        override
        controllerOnly // F:[LPF-4]
    {
        _setLimiter(_lowerBound); // F:[LPF-4,5]
    }

    /// @dev IMPLEMENTATION: setLimiter
    function _setLimiter(uint256 _lowerBound) internal {
        if (_lowerBound == 0 || !_checkCurrentValueInBounds(_lowerBound, _upperBound(_lowerBound))) {
            revert IncorrectLimitsException();
        } // F:[LPF-4]

        lowerBound = _lowerBound; // F:[LPF-5]
        emit SetBounds(lowerBound, _upperBound(_lowerBound)); // F:[LPF-5]
    }

    function _upperBound(uint256 lb) internal view returns (uint256) {
        return (lb * (PERCENTAGE_FACTOR + delta)) / PERCENTAGE_FACTOR; // F:[LPF-5]
    }

    /// @dev Returns the upper bound, calculated based on the lower bound
    function upperBound() external view returns (uint256) {
        return _upperBound(lowerBound); // F:[LPF-5]
    }

    function _getContractValue() internal view virtual returns (uint256);

    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _uBound) internal view returns (bool) {
        uint256 value = _getContractValue();
        if (value < _lowerBound || value > _uBound) {
            return false; // F: [OAPF-5]
        }
        return true;
    }
}
