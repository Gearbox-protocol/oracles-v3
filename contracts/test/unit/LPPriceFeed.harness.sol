// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

import {LPPriceFeed} from "../../oracles/LPPriceFeed.sol";

contract LPPriceFeedHarness is LPPriceFeed {
    PriceFeedType public constant priceFeedType = PriceFeedType.ZERO_ORACLE;
    bytes32 public constant override contractType = "PF_ZERO_ORACLE";
    uint256 public constant override version = 0;

    int256 _answer;
    uint256 _exchangeRate;
    uint256 _scale;

    constructor(address _acl, address _priceOracle, address _lpToken, address _lpContract)
        LPPriceFeed(_acl, _priceOracle, _lpToken, _lpContract)
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

    function hackUpdateBoundsAllowed(bool value) external {
        updateBoundsAllowed = value;
    }

    function hackLastBoundsUpdate(uint256 timestamp) external {
        lastBoundsUpdate = uint40(timestamp);
    }
}
