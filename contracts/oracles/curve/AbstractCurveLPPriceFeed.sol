// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Abstract Curve LP price feed
/// @notice Base contract for Curve stable and crypto pool LP token price feeds.
///         Computes LP token price as LP token exchange rate times pool-specific aggregate of underlying tokens prices.
abstract contract AbstractCurveLPPriceFeed is LPPriceFeed {
    constructor(address addressProvider, address _curvePool) LPPriceFeed(addressProvider, _curvePool, RANGE_WIDTH) {
        _initLimiter();
    }

    /// @notice Returns USD price of the LP token computed as LP token virtual price times
    ///         pool-specific aggregate of underlying tokens prices
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getAggregatePrice();
        answer = int256((_getValidatedLPExchangeRate() * uint256(answer)) / WAD);
        return (0, answer, 0, updatedAt, 0);
    }

    /// @dev Returns pool-specific aggregate of underlying tokens prices, must be implemented by derived price feeds
    function _getAggregatePrice() internal view virtual returns (int256 answer, uint256 updatedAt);

    function getLPExchangeRate() public view override returns (uint256) {
        return uint256(ICurvePool(lpToken).get_virtual_price());
    }
}
