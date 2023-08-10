// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IPriceFeed} from "./IPriceFeed.sol";

interface ILPPriceFeedEvents {
    /// @notice Emitted when new LP token exchange rate bounds are set
    event SetBounds(uint256 lowerBound, uint256 upperBound);

    /// @notice Emitted when permissionless bounds update is allowed or forbidden
    event SetUpdateBoundsAllowed(bool allowed);
}

/// @title LP price feed interface
interface ILPPriceFeed is IPriceFeed, ILPPriceFeedEvents {
    function addressProvider() external view returns (address);

    function lpToken() external view returns (address);
    function lpContract() external view returns (address);

    function lowerBound() external view returns (uint256);
    function upperBound() external view returns (uint256);
    function updateBoundsAllowed() external view returns (bool);

    function getAggregatePrice() external view returns (int256 answer, uint256 updatedAt);
    function getLPExchangeRate() external view returns (uint256 exchangeRate);
    function getScale() external view returns (uint256 scale);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function setUpdateBoundsAllowed(bool allowed) external;
    function setLimiter(uint256 newLowerBound) external;
    function updateBounds(bool updatePrice, bytes calldata data) external;
}
