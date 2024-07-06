// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title crvUSD price feed
/// @notice Computes crvUSD price as product of crvUSD-USDC stableswap pool exchange rate and USDC price feed.
///         While crvUSD is not an LP token itself, the pricing logic is fairly similar, so existing infrastructure
///         is reused. Particularly, the same bounding mechanism is applied to the pool exchange rate.
contract CurveUSDPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_CURVE_USD_ORACLE";

    constructor(
        address _acl,
        address _priceOracle,
        uint256 lowerBound,
        address _crvUSD,
        address _pool,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        SingleAssetLPPriceFeed(_acl, _priceOracle, _crvUSD, _pool, _priceFeed, _stalenessPeriod) // U:[CRV-D-1]
    {
        _setLimiter(lowerBound); // U:[CRV-D-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return ICurvePool(lpContract).price_oracle(); // U:[CRV-D-1]
    }

    function getScale() public pure override returns (uint256) {
        return WAD; // U:[CRV-D-1]
    }
}
