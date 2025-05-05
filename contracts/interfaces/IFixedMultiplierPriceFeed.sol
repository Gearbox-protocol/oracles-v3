// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

/// @title LP price feed interface
interface IFixedMultiplierPriceFeed is IPriceFeed {
    // ------ //
    // EVENTS //
    // ------ //

    /// @notice Emitted when new LP token multiplier is set
    event SetMultiplier(uint256 multiplier);

    // ------ //
    // ERRORS //
    // ------ //

    /// @notice Thrown when trying to set multiplier to zero
    error MultiplierCantBeZeroException();

    // ------- //
    // GETTERS //
    // ------- //

    function multiplier() external view returns (uint256);
    function scale() external view returns (uint256);
    function lpToken() external view returns (address);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function setMultiplier(uint256 newMultiplier) external;
}
