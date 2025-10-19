// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title crvUSD price feed
/// @notice Computes crvUSD price as product of crvUSD-USDC stableswap pool exchange rate and USDC price feed.
///         While crvUSD is not an LP token itself, the pricing logic is fairly similar, so existing infrastructure
///         is reused. Particularly, the same bounding mechanism is applied to the pool exchange rate.
contract CurveUSDPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_11;
    bytes32 public constant override contractType = "PRICE_FEED::CURVE_USD";

    constructor(
        address _owner,
        uint256 _lowerBound,
        address _crvUSD,
        address _pool,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(_owner, _crvUSD, _pool, _priceFeed, _stalenessPeriod) // U:[CRV-D-1]
    {
        _setLimiter(_lowerBound); // U:[CRV-D-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return ICurvePool(lpContract).price_oracle(); // U:[CRV-D-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[CRV-D-1]
    }
}
