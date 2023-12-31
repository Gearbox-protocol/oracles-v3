// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title ERC4626 vault shares price feed
contract ERC4626PriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.ERC4626_VAULT_ORACLE;

    /// @dev Amount of shares comprising a single unit (accounting for decimals)
    uint256 immutable _shareUnit;

    /// @dev Amount of underlying asset comprising a single unit (accounting for decimals)
    uint256 immutable _assetUnit;

    constructor(
        address addressProvider,
        uint256 lowerBound,
        address _vault,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(addressProvider, _vault, _vault, _priceFeed, _stalenessPeriod) // U:[TV-1]
    {
        _shareUnit = 10 ** IERC4626(_vault).decimals();
        _assetUnit = 10 ** ERC20(IERC4626(_vault).asset()).decimals();
        _setLimiter(lowerBound); // U:[TV-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IERC4626(lpToken).convertToAssets(_shareUnit); // U:[TV-1]
    }

    function getScale() public view override returns (uint256) {
        return _assetUnit; // U:[TV-1]
    }
}
