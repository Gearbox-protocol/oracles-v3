// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {LPPriceFeed} from "../../oracles/LPPriceFeed.sol";

contract LPPriceFeedHarness is LPPriceFeed {
    bytes32 public constant override contractType = "PRICE_FEED::LP";
    uint256 public constant override version = 0;

    int256 _answer;
    uint256 _updatedAt;
    uint256 _exchangeRate;
    uint256 _scale;

    constructor(address _owner, address _lpToken, address _lpContract) LPPriceFeed(_owner, _lpToken, _lpContract) {}

    function hackAggregatePriceAndTimestamp(int256 answer, uint256 updatedAt) external {
        _answer = answer;
        _updatedAt = updatedAt;
    }

    function getAggregatePriceAndTimestamp() public view override returns (int256 answer, uint256 updatedAt) {
        return (_answer, _updatedAt);
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
}
