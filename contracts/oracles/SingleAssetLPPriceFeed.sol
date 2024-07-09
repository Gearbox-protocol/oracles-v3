// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LPPriceFeed} from "./LPPriceFeed.sol";
import {PriceFeedParams} from "./PriceFeedParams.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Single-asset LP price feed
/// @notice Base contract for LP tokens with one underlying asset
abstract contract SingleAssetLPPriceFeed is LPPriceFeed {
    address public immutable priceFeed;
    uint32 public immutable stalenessPeriod;
    bool public immutable skipCheck;

    constructor(
        address _acl,
        address _priceOracle,
        address _lpToken,
        address _lpContract,
        address _priceFeed,
        uint32 _stalenessPeriod
    )
        LPPriceFeed(_acl, _priceOracle, _lpToken, _lpContract) // U:[SAPF-1]
        nonZeroAddress(_priceFeed) // U:[SAPF-1]
    {
        priceFeed = _priceFeed; // U:[SAPF-1]
        stalenessPeriod = _stalenessPeriod; // U:[SAPF-1]
        skipCheck = _validatePriceFeed(_priceFeed, _stalenessPeriod); // U:[SAPF-1]
    }

    function getAggregatePrice() public view override returns (int256 answer) {
        answer = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck); // U:[SAPF-2]
    }
}
