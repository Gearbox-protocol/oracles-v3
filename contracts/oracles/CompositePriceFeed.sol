// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {AbstractPriceFeed} from "./AbstractPriceFeed.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType, IPriceFeedType} from "../interfaces/IPriceFeedType.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// EXCEPTIONS
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Price feed that composes an base asset-denominated price feed with a USD one
/// @notice Used for better price tracking for correlated assets (such as stETH or WBTC) or on networks where
///         only feeds for the native tokens exist
contract CompositePriceFeed is AbstractPriceFeed, IPriceFeedType {
    PriceFeedType public constant override priceFeedType = PriceFeedType.COMPOSITE_ORACLE;
    uint256 public constant override version = 3_00;
    bool public constant override skipPriceCheck = true;

    /// @dev Chainlink base asset price feed for the target asset
    address public immutable targetToBasePriceFeed;

    /// @dev Chainlink Base asset / USD price feed
    address public immutable baseToUsdPriceFeed;

    /// @dev Decimals of the returned result.
    uint8 public immutable override decimals;

    /// @dev 10 ^ Decimals of Target / Base price feed, to divide the product of answers
    int256 public immutable answerDenominator;

    /// @dev Price feed description
    string public override description;

    /// @dev Constructor
    /// @param _targetToBasePriceFeed Base asset price feed for target asset
    /// @param _baseToUsdPriceFeed USD price feed for base asset
    constructor(address _targetToBasePriceFeed, address _baseToUsdPriceFeed) {
        targetToBasePriceFeed = _targetToBasePriceFeed;
        baseToUsdPriceFeed = _baseToUsdPriceFeed;

        description =
            string(abi.encodePacked(AggregatorV3Interface(targetToBasePriceFeed).description(), " to USD Composite"));
        decimals = AggregatorV3Interface(baseToUsdPriceFeed).decimals();
        answerDenominator = int256(10 ** AggregatorV3Interface(targetToBasePriceFeed).decimals());
    }

    /// @dev Returns the composite USD-denominated price of the asset, computed as (Target / base rate * base / USD rate)
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (int256 answer0, uint256 updatedAt0) = _getValidatedPrice(targetToBasePriceFeed, 2 hours);
        (answer, updatedAt) = _getValidatedPrice(baseToUsdPriceFeed, 2 hours);

        answer = (answer0 * answer) / answerDenominator;
    }
}
