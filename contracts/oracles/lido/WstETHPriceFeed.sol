// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title wstETH price feed
contract WstETHPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.WSTETH_ORACLE;

    constructor(
        address addressProvider,
        uint256 lowerBound,
        address _wstETH,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(addressProvider, _wstETH, _wstETH, _priceFeed, _stalenessPeriod) // U:[LDO-1]
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
