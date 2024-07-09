// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title Yearn price feed
contract YearnPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_YEARN_ORACLE";

    /// @dev Scale of yVault's pricePerShare
    uint256 immutable _scale;

    constructor(
        address _acl,
        address _priceOracle,
        uint256 lowerBound,
        address _yVault,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(_acl, _priceOracle, _yVault, _yVault, _priceFeed, _stalenessPeriod) // U:[YFI-1]
    {
        _scale = 10 ** IYVault(_yVault).decimals();
        _setLimiter(lowerBound); // U:[YFI-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IYVault(lpToken).pricePerShare(); // U:[YFI-1]
    }

    function getScale() public view override returns (uint256) {
        return _scale; // U:[YFI-1]
    }
}
