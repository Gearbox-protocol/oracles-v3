// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title wstETH price feed
contract WstETHPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_WSTETH_ORACLE";

    constructor(
        address _acl,
        address _priceOracle,
        uint256 lowerBound,
        address _wstETH,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(_acl, _priceOracle, _wstETH, _wstETH, _priceFeed, _stalenessPeriod) // U:[LDO-1]
    {
        _setLimiter(lowerBound); // U:[LDO-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IwstETH(lpToken).stEthPerToken(); // U:[LDO-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[LDO-1]
    }
}
