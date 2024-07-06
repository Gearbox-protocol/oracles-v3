// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

import {SingleAssetLPPriceFeed} from "../../oracles/SingleAssetLPPriceFeed.sol";

contract SingleAssetLPPriceFeedHarness is SingleAssetLPPriceFeed {
    PriceFeedType public constant priceFeedType = PriceFeedType.ZERO_ORACLE;
    bytes32 public constant override contractType = "PF_ZERO_ORACLE";
    uint256 public constant override version = 0;

    constructor(
        address _acl,
        address _priceOracle,
        address _lpToken,
        address _lpContract,
        address _priceFeed,
        uint32 _stalenessPeriod
    ) SingleAssetLPPriceFeed(_acl, _priceOracle, _lpToken, _lpContract, _priceFeed, _stalenessPeriod) {}

    function getLPExchangeRate() public view override returns (uint256 exchangeRate) {}

    function getScale() public view override returns (uint256 scale) {}
}
