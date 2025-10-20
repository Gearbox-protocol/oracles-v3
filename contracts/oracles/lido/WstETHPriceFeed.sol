// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title wstETH price feed
contract WstETHPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_11;
    bytes32 public constant override contractType = "PRICE_FEED::WSTETH";

    constructor(address _owner, uint256 _lowerBound, address _wstETH, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(_owner, _wstETH, _wstETH, _priceFeed, _stalenessPeriod) // U:[LDO-1]
    {
        _setLimiter(_lowerBound); // U:[LDO-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IwstETH(lpToken).stEthPerToken(); // U:[LDO-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[LDO-1]
    }
}
