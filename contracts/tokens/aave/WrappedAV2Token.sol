// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IAToken} from "../../interfaces/aave/IAToken.sol";
import {ILendingPool} from "../../interfaces/aave/ILendingPool.sol";
import {IWrappedAV2Token} from "../../interfaces/aave/IWrappedAV2Token.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Wrapped aToken
/// @notice Non-rebasing wrapper of Aave V2 aToken
/// @dev Ignores any Aave incentives
contract WrappedAV2Token is ERC20, IWrappedAV2Token, SanityCheckTrait {
    using SafeERC20 for IERC20;

    /// @inheritdoc IWrappedAV2Token
    address public immutable override aToken;

    /// @inheritdoc IWrappedAV2Token
    address public immutable override underlying;

    /// @inheritdoc IWrappedAV2Token
    address public immutable override lendingPool;

    /// @dev aToken's normalized income (aka interest accumulator) at the moment of waToken creation
    uint256 private immutable _normalizedIncome;

    uint8 private immutable _decimals;

    /// @notice Constructor
    /// @param _aToken Underlying aToken
    constructor(address _aToken)
        ERC20(
            _aToken != address(0) ? string(abi.encodePacked("Wrapped ", IAToken(_aToken).name())) : "",
            _aToken != address(0) ? string(abi.encodePacked("w", IAToken(_aToken).symbol())) : ""
        )
        nonZeroAddress(_aToken)
    {
        aToken = _aToken; // F: [WAT-2]
        underlying = IAToken(_aToken).UNDERLYING_ASSET_ADDRESS(); // F: [WAT-2]
        lendingPool = address(IAToken(_aToken).POOL()); // F: [WAT-2]
        _decimals = IAToken(aToken).decimals(); // F: [WAT-2]

        _normalizedIncome = ILendingPool(lendingPool).getReserveNormalizedIncome(address(underlying));
        IERC20(underlying).approve(address(lendingPool), type(uint256).max);
    }

    /// @inheritdoc IWrappedAV2Token
    function balanceOfUnderlying(address account) external view override returns (uint256) {
        return (balanceOf(account) * exchangeRate()) / WAD; // F: [WAT-3]
    }

    /// @inheritdoc IWrappedAV2Token
    function exchangeRate() public view override returns (uint256) {
        return WAD * ILendingPool(lendingPool).getReserveNormalizedIncome(address(underlying)) / _normalizedIncome; // F: [WAT-4]
    }

    /// @inheritdoc IWrappedAV2Token
    function deposit(uint256 assets) external override returns (uint256 shares) {
        IAToken(aToken).transferFrom(msg.sender, address(this), assets);
        shares = _deposit(assets); // F: [WAT-5]
    }

    /// @inheritdoc IWrappedAV2Token
    function depositUnderlying(uint256 assets) external override returns (uint256 shares) {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), assets);
        _ensureAllowance(assets);
        ILendingPool(lendingPool).deposit(address(underlying), assets, address(this), 0); // F: [WAT-6]
        shares = _deposit(assets); // F: [WAT-6]
    }

    /// @inheritdoc IWrappedAV2Token
    function withdraw(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares); // F: [WAT-7]
        IAToken(aToken).transfer(msg.sender, assets);
    }

    /// @inheritdoc IWrappedAV2Token
    function withdrawUnderlying(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares); // F: [WAT-8]
        ILendingPool(lendingPool).withdraw(address(underlying), assets, msg.sender); // F: [WAT-8]
    }

    /// @dev Internal implementation of deposit
    function _deposit(uint256 assets) internal returns (uint256 shares) {
        shares = (assets * WAD) / exchangeRate();
        _mint(msg.sender, shares); // F: [WAT-5, WAT-6]
        emit Deposit(msg.sender, assets, shares); // F: [WAT-5, WAT-6]
    }

    /// @dev Internal implementation of withdraw
    function _withdraw(uint256 shares) internal returns (uint256 assets) {
        assets = (shares * exchangeRate()) / WAD;
        _burn(msg.sender, shares); // F: [WAT-7, WAT-8]
        emit Withdraw(msg.sender, assets, shares); // F: [WAT-7, WAT-8]
    }

    /// @dev Gives lending pool max approval for underlying if it falls below `amount`
    function _ensureAllowance(uint256 amount) internal {
        if (IERC20(underlying).allowance(address(this), address(lendingPool)) < amount) {
            IERC20(underlying).approve(address(lendingPool), type(uint256).max); // [WAT-9]
        }
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }
}
