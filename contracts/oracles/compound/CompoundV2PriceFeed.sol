// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {SingleAssetLPFeed} from "../SingleAssetLPFeed.sol";

import {ICToken} from "../../interfaces/compound/ICToken.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Yearn price feed
contract CompoundV2PriceFeed is SingleAssetLPFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.COMPOUND_V2_ORACLE;
    uint256 public constant override version = 3_00;

    constructor(address addressProvider, address _yVault, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPFeed(addressProvider, _yVault, _priceFeed, _stalenessPeriod)
    {
        _setLimiter(ICToken(lpToken).exchangeRateCurrent());
    }

    function _getContractValue() internal view override returns (uint256) {
        return ICToken(lpToken).exchangeRateStored();
    }
}
