// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

/// @title LP price feed interface
interface IFixedRatePriceFeed is IPriceFeed {
    // ------ //
    // EVENTS //
    // ------ //

    /// @notice Emitted when new LP token rate is set
    event SetRate(uint256 rate);

    // ------ //
    // ERRORS //
    // ------ //

    /// @notice Thrown when trying to set exchange rate to zero
    error RateCantBeZeroException();

    // ------- //
    // GETTERS //
    // ------- //

    function rate() external view returns (uint256);
    function scale() external view returns (uint256);
    function lpToken() external view returns (address);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function setRate(uint256 newRate) external;
}
