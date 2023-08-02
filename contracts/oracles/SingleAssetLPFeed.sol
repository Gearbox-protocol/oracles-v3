// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {LPPriceFeed} from "./LPPriceFeed.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Aave V2 wrapped aToken price feed
abstract contract SingleAssetLPFeed is LPPriceFeed {
    /// @dev Chainlink price feed for the Vault's underlying
    address public immutable priceFeed;
    uint32 public immutable stalenessPeriod;

    address public immutable lpToken;

    uint256 public immutable decimalsDivider;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(address addressProvider, address _lpToken, address _priceFeed, uint32 _stalenessPeriod)
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _lpToken != address(0) ? string(abi.encodePacked(IERC20Metadata(_lpToken).name(), " priceFeed")) : ""
        )
        nonZeroAddress(_lpToken)
        nonZeroAddress(_priceFeed)
    {
        _validatePriceFeed(_priceFeed, _stalenessPeriod);

        lpToken = _lpToken;
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        decimalsDivider = 10 ** IERC20Metadata(_lpToken).decimals();
    }

    /// @dev Returns the USD price of the waToken
    /// @notice Computes the waToken price as (price(underlying) * exchangeRate)
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getValidatedPrice(priceFeed, stalenessPeriod); // F:[OCLP-6]

        uint256 validateContractValue = _getValidatedContractValue();

        answer = int256((validateContractValue * uint256(answer)) / decimalsDivider); // F: [OAPF-3]
    }
}
