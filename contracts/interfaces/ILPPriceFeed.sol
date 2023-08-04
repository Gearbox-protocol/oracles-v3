// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IPriceFeed} from "./IPriceFeed.sol";

interface ILPPriceFeedEvents {
    /// @notice Emitted when new LP token exchange rate bounds are set
    event SetBounds(uint256 lowerBound, uint256 upperBound);
}

/// @title LP price feed interface
interface ILPPriceFeed is IPriceFeed, ILPPriceFeedEvents {
    function lpToken() external view returns (address);
    function lowerBound() external view returns (uint256);
    function upperBound() external view returns (uint256);
    function delta() external view returns (uint256);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function setLimiter(uint256 newLowerBound) external;
}
