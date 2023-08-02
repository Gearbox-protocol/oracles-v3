// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {SingleAssetLPFeed} from "../SingleAssetLPFeed.sol";

import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Yearn price feed
contract WstETHPriceFeed is SingleAssetLPFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.WSTETH_ORACLE;

    uint256 public constant override version = 3_00;

    constructor(address addressProvider, address _wstETH, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPFeed(addressProvider, _wstETH, _priceFeed, _stalenessPeriod)
    {
        _setLimiter(_getContractValue());
    }

    function _getContractValue() internal view override returns (uint256) {
        return IwstETH(lpToken).stEthPerToken();
    }
}
