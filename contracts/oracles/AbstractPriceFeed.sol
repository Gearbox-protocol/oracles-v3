// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {ILPPriceFeed} from "../interfaces/ILPPriceFeed.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLNonReentrantTrait.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// EXCEPTIONS
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

struct PriceFeedParams {
    address priceFeed;
    uint32 stalenessPeriod;
}

abstract contract AbstractPriceFeed is AggregatorV3Interface, PriceFeedValidationTrait {
    function _getValidatedPrice(address priceFeed, uint32 stalenessPeriod)
        internal
        view
        returns (int256 answer, uint256 updatedAt)
    {
        (, answer,, updatedAt,) = AggregatorV3Interface(priceFeed).latestRoundData(); // F:[OCLP-6]
        _checkAnswer(answer, updatedAt, stalenessPeriod);
    }

    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert NotImplementedException();
    }
}
