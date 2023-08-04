// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

import {IAToken} from "../../interfaces/aave/IAToken.sol";
import {ILendingPool} from "../../interfaces/aave/ILendingPool.sol";
import {IWrappedATokenV2} from "../../interfaces/aave/IWrappedATokenV2.sol";

/// @title Wrapped aToken V2
/// @notice Non-rebasing wrapper of Aave V2 aToken
/// @dev Ignores any Aave incentives
contract WrappedATokenV2 is ERC20, SanityCheckTrait, IWrappedATokenV2 {
    using SafeERC20 for ERC20;

    /// @inheritdoc IWrappedATokenV2
    address public immutable override aToken;

    /// @inheritdoc IWrappedATokenV2
    address public immutable override underlying;

    /// @inheritdoc IWrappedATokenV2
    address public immutable override lendingPool;

    /// @dev aToken's normalized income (aka interest accumulator) at the moment of waToken creation
    uint256 private immutable _normalizedIncome;

    /// @dev waToken decimals
    uint8 private immutable _decimals;

    /// @notice Constructor
    /// @param _aToken Underlying aToken address
    constructor(address _aToken)
        ERC20(
            address(_aToken) != address(0) ? string(abi.encodePacked("Wrapped ", ERC20(_aToken).name())) : "",
            address(_aToken) != address(0) ? string(abi.encodePacked("w", ERC20(_aToken).symbol())) : ""
        )
        nonZeroAddress(_aToken) // U:[WAT-1]
    {
        aToken = _aToken; // U:[WAT-2]
        underlying = IAToken(aToken).UNDERLYING_ASSET_ADDRESS(); // U:[WAT-2]
        lendingPool = address(IAToken(aToken).POOL()); // U:[WAT-2]
        _normalizedIncome = ILendingPool(lendingPool).getReserveNormalizedIncome(address(underlying));
        _decimals = IAToken(aToken).decimals(); // U:[WAT-2]
        ERC20(underlying).approve(lendingPool, type(uint256).max);
    }

    /// @inheritdoc IWrappedATokenV2
    function decimals() public view override(ERC20, IWrappedATokenV2) returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IWrappedATokenV2
    function balanceOfUnderlying(address account) external view override returns (uint256) {
        return (balanceOf(account) * exchangeRate()) / WAD; // U:[WAT-3]
    }

    /// @inheritdoc IWrappedATokenV2
    function exchangeRate() public view override returns (uint256) {
        return WAD * ILendingPool(lendingPool).getReserveNormalizedIncome(address(underlying)) / _normalizedIncome; // U:[WAT-4]
    }

    /// @inheritdoc IWrappedATokenV2
    function deposit(uint256 assets) external override returns (uint256 shares) {
        ERC20(aToken).transferFrom(msg.sender, address(this), assets);
        shares = _deposit(assets); // U:[WAT-5]
    }

    /// @inheritdoc IWrappedATokenV2
    function depositUnderlying(uint256 assets) external override returns (uint256 shares) {
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), assets);
        _ensureAllowance(assets);
        ILendingPool(lendingPool).deposit(address(underlying), assets, address(this), 0); // U:[WAT-6]
        shares = _deposit(assets); // U:[WAT-6]
    }

    /// @inheritdoc IWrappedATokenV2
    function withdraw(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares); // U:[WAT-7]
        ERC20(aToken).transfer(msg.sender, assets);
    }

    /// @inheritdoc IWrappedATokenV2
    function withdrawUnderlying(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares); // U:[WAT-8]
        ILendingPool(lendingPool).withdraw(address(underlying), assets, msg.sender); // U:[WAT-8]
    }

    /// @dev Internal implementation of deposit
    function _deposit(uint256 assets) internal returns (uint256 shares) {
        shares = (assets * WAD) / exchangeRate();
        _mint(msg.sender, shares); // U:[WAT-5,6]
        emit Deposit(msg.sender, assets, shares); // U:[WAT-5,6]
    }

    /// @dev Internal implementation of withdraw
    function _withdraw(uint256 shares) internal returns (uint256 assets) {
        assets = (shares * exchangeRate()) / WAD;
        _burn(msg.sender, shares); // U:[WAT-7,8]
        emit Withdraw(msg.sender, assets, shares); // U:[WAT-7,8]
    }

    /// @dev Gives lending pool max approval for underlying if it falls below `amount`
    function _ensureAllowance(uint256 amount) internal {
        if (ERC20(underlying).allowance(address(this), address(lendingPool)) < amount) {
            ERC20(underlying).approve(address(lendingPool), type(uint256).max); // [WAT-9]
        }
    }
}
