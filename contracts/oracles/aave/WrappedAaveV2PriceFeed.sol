// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {IWAToken} from "../../interfaces/aave/IWAToken.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title Aave V2 waToken price feed
contract WrappedAaveV2PriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.WRAPPED_AAVE_V2_ORACLE;

    constructor(
        address addressProvider,
        uint256 lowerBound,
        address _waToken,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(addressProvider, _waToken, _waToken, _priceFeed, _stalenessPeriod) // U:[AAVE-1]
    {
        _setLimiter(lowerBound); // U:[AAVE-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IWAToken(lpToken).exchangeRate(); // U:[AAVE-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[AAVE-1]
    }
}
