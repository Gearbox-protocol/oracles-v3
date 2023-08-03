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
    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.ERC4626_VAULT_ORACLE;

    /// @notice Amount of shares comprising a single unit (accounting for decimals)
    uint256 public immutable shareUnit;

    /// @notice Amount of underlying asset comprising a single unit (accounting for decimals)
    uint256 public immutable assetUnit;

    constructor(address addressProvider, address _vault, address _assetPriceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(addressProvider, _vault, _assetPriceFeed, _stalenessPeriod)
    {
        shareUnit = 10 ** IERC4626(_vault).decimals(); // U:[TVPF-2]
        assetUnit = 10 ** ERC20(IERC4626(_vault).asset()).decimals(); // U:[TVPF-2]
        _initLimiter();
    }

    function _getLPExchangeRate() internal view override returns (uint256) {
        return IERC4626(lpToken).convertToAssets(shareUnit); // U:[TVPF-3]
    }

    function _getScale() internal view override returns (uint256) {
        return assetUnit;
    }
}
