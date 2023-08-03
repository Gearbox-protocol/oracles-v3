// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

struct PriceFeedParams {
    address priceFeed;
    uint32 stalenessPeriod;
}

/// @title Abstract price feed
/// @notice Base contract for all price feeds
abstract contract AbstractPriceFeed is IPriceFeed, PriceFeedValidationTrait {
    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true;

    /// @dev Returns answer from a price feed with optional sanity and staleness checks
    /// @dev When computing LP token price, this MUST be used to get prices of underlying tokens
    function _getValidatedPrice(address priceFeed, uint32 stalenessPeriod, bool skipCheck)
        internal
        view
        returns (int256 answer, uint256 updatedAt)
    {
        (, answer,, updatedAt,) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (!skipCheck) _checkAnswer(answer, updatedAt, stalenessPeriod);
    }

    /// @dev Not implemented since Gearbox price feeds don't provide historical data
    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert NotImplementedException();
    }
}
