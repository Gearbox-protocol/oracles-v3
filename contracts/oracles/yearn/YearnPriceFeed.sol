// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title Yearn price feed
contract YearnPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.YEARN_ORACLE;

    /// @dev Scale of yVault's pricePerShare
    uint256 immutable _scale;

    constructor(address addressProvider, address _yVault, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(addressProvider, _yVault, _priceFeed, _stalenessPeriod)
    {
        _scale = 10 ** IYVault(_yVault).decimals();
        _initLimiter();
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IYVault(lpToken).pricePerShare();
    }

    function getScale() public view override returns (uint256) {
        return _scale;
    }
}
