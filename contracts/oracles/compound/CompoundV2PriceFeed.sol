// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {ICToken} from "../../interfaces/compound/ICToken.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title Compound V2 cToken price feed
contract CompoundV2PriceFeed is SingleAssetLPPriceFeed {
    /// @notice Contract version
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.COMPOUND_V2_ORACLE;

    constructor(address addressProvider, address _cToken, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(addressProvider, _cToken, _priceFeed, _stalenessPeriod)
    {
        _initLimiter();
    }

    function _getLPExchangeRate() internal view override returns (uint256) {
        return ICToken(lpToken).exchangeRateStored();
    }

    function _getScale() internal pure override returns (uint256) {
        return WAD;
    }
}
