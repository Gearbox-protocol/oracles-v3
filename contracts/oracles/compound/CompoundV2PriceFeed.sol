// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {ICToken} from "../../interfaces/compound/ICToken.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";

/// @title Compound V2 cToken price feed
contract CompoundV2PriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    bytes32 public constant contractType = "PF_COMPOUND_V2_ORACLE";

    constructor(
        address _acl,
        address _priceOracle,
        uint256 lowerBound,
        address _cToken,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(_acl, _priceOracle, _cToken, _cToken, _priceFeed, _stalenessPeriod) // U:[COMP-1]
    {
        _setLimiter(lowerBound); // U:[COMP-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return ICToken(lpToken).exchangeRateStored(); // U:[COMP-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[COMP-1]
    }
}
