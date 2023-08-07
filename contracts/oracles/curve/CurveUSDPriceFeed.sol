// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

interface IPool {
    function price_oracle() external view returns (uint256);
}

/// @title crvUSD price feed
/// @notice Computes crvUSD price as product of crvUSD-USDC stableswap pool exchange rate and USDC price feed.
///         While crvUSD is not an LP token itself, the pricing logic is fairly similar, so existing infrastructure
///         is reused. Particularly, the same bounding mechanism is applied to the pool exchange rate.
contract CurveUSDPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.CURVE_USD_ORACLE;

    constructor(address addressProvider, address _crvUSD, address _pool, address _priceFeed, uint32 _stalenessPeriod)
        SingleAssetLPPriceFeed(addressProvider, _crvUSD, _pool, _priceFeed, _stalenessPeriod)
    {
        _initLimiter();
    }

    function getLPExchangeRate() public view override returns (uint256) {
        return IPool(lpContract).price_oracle();
    }

    function getScale() public pure override returns (uint256) {
        return WAD;
    }
}
