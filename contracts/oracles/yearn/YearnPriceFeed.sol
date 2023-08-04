// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title Yearn price feed
contract YearnPriceFeed is SingleAssetLPPriceFeed {
    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.YEARN_ORACLE;

    /// @notice Scale of yVault's pricePerShare
    uint256 public immutable scale;

    constructor(address addressProvider, address _yVault, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(addressProvider, _yVault, _priceFeed, _stalenessPeriod)
    {
        scale = 10 ** IYVault(_yVault).decimals();
        _initLimiter();
    }

    function _getLPExchangeRate() internal view override returns (uint256) {
        return IYVault(lpToken).pricePerShare();
    }

    function _getScale() internal view override returns (uint256) {
        return scale;
    }
}
