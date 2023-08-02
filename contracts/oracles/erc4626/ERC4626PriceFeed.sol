// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {SingleAssetLPFeed} from "../SingleAssetLPFeed.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

uint256 constant RANGE_WIDTH = 200;

/// @title ERC4626 vault shares price feed
contract ERC4626PriceFeed is SingleAssetLPFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.ERC4626_VAULT_ORACLE;
    uint256 public constant override version = 3_00;

    /// @notice Amount of shares comprising a single unit (accounting for decimals)
    uint256 public immutable vaultShareUnit;

    /// @notice Constructor
    /// @param addressProvider Address provider contract
    /// @param _vault Vault to compute prices for
    /// @param _assetPriceFeed Vault's underlying asset price feed
    constructor(address addressProvider, address _vault, address _assetPriceFeed, uint32 _stalenessPeriod)
        SingleAssetLPFeed(addressProvider, _vault, _assetPriceFeed, _stalenessPeriod)
        nonZeroAddress(_vault) // U:[TVPF-1]
        nonZeroAddress(_assetPriceFeed) // U:[TVPF-1]
    {
        vaultShareUnit = 10 ** IERC4626(_vault).decimals(); // U:[TVPF-2]

        // it updates limiter with the current value
        _setLimiter(_getContractValue()); // U:[TVPF-2]
    }

    function _getContractValue() internal view override returns (uint256) {
        return IERC4626(lpToken).convertToAssets(vaultShareUnit); // U:[TVPF-3]
    }
}
