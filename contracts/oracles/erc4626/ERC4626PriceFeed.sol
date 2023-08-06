// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title ERC4626 vault shares price feed
contract ERC4626PriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.ERC4626_VAULT_ORACLE;

    /// @dev Amount of shares comprising a single unit (accounting for decimals)
    uint256 immutable _shareUnit;

    /// @dev Amount of underlying asset comprising a single unit (accounting for decimals)
    uint256 immutable _assetUnit;

    constructor(address addressProvider, address _vault, address _assetPriceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(addressProvider, _vault, _assetPriceFeed, _stalenessPeriod)
    {
        _shareUnit = 10 ** IERC4626(_vault).decimals();
        _assetUnit = 10 ** ERC20(IERC4626(_vault).asset()).decimals();
        _initLimiter();
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IERC4626(lpToken).convertToAssets(_shareUnit);
    }

    function getScale() public view override returns (uint256) {
        return _assetUnit;
    }
}
