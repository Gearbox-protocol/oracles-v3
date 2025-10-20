// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {SingleAssetLPPriceFeed} from "../../oracles/SingleAssetLPPriceFeed.sol";

contract SingleAssetLPPriceFeedHarness is SingleAssetLPPriceFeed {
    bytes32 public constant override contractType = "PRICE_FEED::SINGLE_ASSET_LP";
    uint256 public constant override version = 0;

    constructor(address _owner, address _lpToken, address _lpContract, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(_owner, _lpToken, _lpContract, _priceFeed, _stalenessPeriod)
    {}

    function getLPExchangeRate() public view override returns (uint256 exchangeRate) {}

    function getScale() public view override returns (uint256 scale) {}
}
