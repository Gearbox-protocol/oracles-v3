// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "./LPPriceFeed.sol";
import {PriceFeedParams} from "./AbstractPriceFeed.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Single-asset LP price feed
/// @notice Base contract for LP tokens with one underlying asset for which LP token price
///         is a product of LP token exchange rate and underlying token price
abstract contract SingleAssetLPPriceFeed is LPPriceFeed {
    /// @notice Underlying token price feed
    address public immutable priceFeed;
    uint32 public immutable stalenessPeriod;
    bool public immutable skipCheck;

    /// @notice Constructor
    /// @param addressProvider Address provider contract address
    /// @param _lpToken LP token for which the prices are computed
    /// @param _priceFeed LP token's underlying token price feed
    /// @param _stalenessPeriod Underlying price feed staleness period, must be non-zero unless it performs own checks
    constructor(address addressProvider, address _lpToken, address _priceFeed, uint32 _stalenessPeriod)
        LPPriceFeed(addressProvider, _lpToken, RANGE_WIDTH)
        nonZeroAddress(_priceFeed)
    {
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        skipCheck = _validatePriceFeed(_priceFeed, _stalenessPeriod);
    }

    /// @notice Returns USD price of the LP token computed as LP token exchange rate times USD price of underlying token
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck); // F:[OCLP-6]
        answer = int256((_getValidatedLPExchangeRate() * uint256(answer)) / _getScale()); // F: [OAPF-3]
        return (0, answer, 0, updatedAt, 0);
    }

    /// @dev Returns LP token exchange rate scale, must be implemented by derived price feeds
    function _getScale() internal view virtual returns (uint256 scale);
}
