// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

/// @title LP price feed interface
interface ILPPriceFeed is IPriceFeed {
    // ------ //
    // EVENTS //
    // ------ //

    /// @notice Emitted when new LP token exchange rate bounds are set
    event SetBounds(uint256 lowerBound, uint256 upperBound);

    // ------ //
    // ERRORS //
    // ------ //

    /// @notice Thrown when trying to set exchange rate lower bound to zero
    error LowerBoundCantBeZeroException();

    /// @notice Thrown when exchange rate falls below lower bound during price calculation
    ///         or new boudns don't contain exchange rate during bounds update
    error ExchangeRateOutOfBoundsException();

    // ------- //
    // GETTERS //
    // ------- //

    function lpToken() external view returns (address);
    function lpContract() external view returns (address);

    function lowerBound() external view returns (uint256);
    function upperBound() external view returns (uint256);

    function getAggregatePrice() external view returns (int256 answer);
    function getLPExchangeRate() external view returns (uint256 exchangeRate);
    function getScale() external view returns (uint256 scale);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function setLimiter(uint256 newLowerBound) external;
}
