// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

import {LPPriceFeed} from "../../oracles/LPPriceFeed.sol";

contract LPPriceFeedHarness is LPPriceFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.ZERO_ORACLE;
    uint256 public constant override version = 0;

    int256 _answer;
    uint256 _exchangeRate;
    uint256 _scale;

    constructor(address _addressProvider, address _lpToken, address _lpContract)
        LPPriceFeed(_addressProvider, _lpToken, _lpContract)
    {}

    function hackAggregatePrice(int256 answer) external {
        _answer = answer;
    }

    function getAggregatePrice() public view override returns (int256 answer) {
        return _answer;
    }

    function hackLPExchangeRate(uint256 exchangeRate) external {
        _exchangeRate = exchangeRate;
    }

    function getLPExchangeRate() public view override returns (uint256 exchangeRate) {
        return _exchangeRate;
    }

    function hackScale(uint256 scale) external {
        _scale = scale;
    }

    function getScale() public view override returns (uint256 scale) {
        return _scale;
    }

    function hackLowerBound(uint256 newLowerBound) external {
        lowerBound = newLowerBound;
    }

    function initLimiterExposed() external {
        _initLimiter();
    }

    function hackUpdateBoundsAllowed(bool value) external {
        updateBoundsAllowed = value;
    }
}
