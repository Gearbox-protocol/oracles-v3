// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {AbstractPriceFeed} from "./AbstractPriceFeed.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType, IPriceFeedType} from "../interfaces/IPriceFeedType.sol";

// EXCEPTIONS
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

interface ChainlinkReadableAggregator {
    function aggregator() external view returns (address);

    function phaseAggregators(uint16 idx) external view returns (AggregatorV2V3Interface);

    function phaseId() external view returns (uint16);
}

/// @title Price feed with an upper bound on price
/// @notice Used to limit prices on assets that should not rise above
///         a certain level, such as stablecoins and other pegged assets
contract BoundedPriceFeed is ChainlinkReadableAggregator, AbstractPriceFeed, IPriceFeedType {
    PriceFeedType public constant override priceFeedType = PriceFeedType.BOUNDED_ORACLE;
    uint256 public constant override version = 3_00;
    bool public constant override skipPriceCheck = false;

    /// @dev Chainlink price feed for the Vault's underlying
    address public immutable priceFeed;

    /// @dev The upper bound on Chainlink price for the asset
    int256 public immutable upperBound;

    /// @dev Decimals of the returned result.
    uint8 public immutable override decimals;

    /// @dev Price feed description
    string public override description;

    /// @dev Constructor
    /// @param _priceFeed Chainlink price feed to receive results from
    /// @param _upperBound Initial upper bound for the Chainlink price
    constructor(address _priceFeed, int256 _upperBound) {
        priceFeed = _priceFeed;
        description = string(abi.encodePacked(AggregatorV3Interface(priceFeed).description(), " Bounded"));
        decimals = AggregatorV3Interface(priceFeed).decimals();
        upperBound = _upperBound;
    }

    /// @dev Returns the value if it is below the upper bound, otherwise returns the upper bound
    /// @param value Value to be checked and bounded
    function _upperBoundValue(int256 value) internal view returns (int256) {
        return (value > upperBound) ? upperBound : value;
    }

    /// @dev Returns the upper-bounded USD price of the token
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getValidatedPrice(priceFeed, 2 hours);
        answer = _upperBoundValue(answer);
    }

    /// @dev Returns the current phase's aggregator address
    function aggregator() external view returns (address) {
        return ChainlinkReadableAggregator(address(priceFeed)).aggregator();
    }

    /// @dev Returns a phase aggregator by index
    function phaseAggregators(uint16 idx) external view returns (AggregatorV2V3Interface) {
        return ChainlinkReadableAggregator(address(priceFeed)).phaseAggregators(idx);
    }

    function phaseId() external view returns (uint16) {
        return ChainlinkReadableAggregator(address(priceFeed)).phaseId();
    }
}
