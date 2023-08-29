// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IWrappedATokenV2Events {
    /// @notice Emitted on deposit
    /// @param account Account that performed deposit
    /// @param assets Amount of deposited aTokens
    /// @param shares Amount of waTokens minted to account
    event Deposit(address indexed account, uint256 assets, uint256 shares);

    /// @notice Emitted on withdrawal
    /// @param account Account that performed withdrawal
    /// @param assets Amount of withdrawn aTokens
    /// @param shares Amount of waTokens burnt from account
    event Withdraw(address indexed account, uint256 assets, uint256 shares);
}

/// @title Wrapped aToken V2 interface
interface IWrappedATokenV2 is IERC20Metadata, IWrappedATokenV2Events {
    function aToken() external view returns (address);

    function underlying() external view returns (address);

    function lendingPool() external view returns (address);

    function balanceOfUnderlying(address account) external view returns (uint256);

    function exchangeRate() external view returns (uint256);

    function deposit(uint256 assets) external returns (uint256 shares);

    function depositUnderlying(uint256 assets) external returns (uint256 shares);

    function withdraw(uint256 shares) external returns (uint256 assets);

    function withdrawUnderlying(uint256 shares) external returns (uint256 assets);
}
