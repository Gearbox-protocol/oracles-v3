// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStateSerializer} from "../../interfaces/IStateSerializer.sol";
import {IMellowVault} from "../../interfaces/mellow/IMellowVault.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Mellow LRT price feed
contract MellowLRTPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_10;
    PriceFeedType public constant override priceFeedType = PriceFeedType.MELLOW_LRT_ORACLE;

    /// @dev Amount of base token comprising a single unit (accounting for decimals)
    uint256 immutable _baseTokenUnit;

    constructor(
        address _acl,
        address _priceOracle,
        uint256 lowerBound,
        address _vault,
        address _priceFeed,
        uint32 _stalenessPeriod,
        address baseToken
    ) SingleAssetLPPriceFeed(_acl, _priceOracle, _vault, _vault, _priceFeed, _stalenessPeriod) {
        _baseTokenUnit = 10 ** ERC20(baseToken).decimals();
        _setLimiter(lowerBound);
    }

    function getLPExchangeRate() public view override returns (uint256) {
        IMellowVault.ProcessWithdrawalsStack memory stack = IMellowVault(lpToken).calculateStack();
        return stack.totalValue * WAD / stack.totalSupply;
    }

    function getScale() public view override returns (uint256) {
        return _baseTokenUnit;
    }

    function serialize() public view returns (bytes memory serializedData) {
        return abi.encode(
            priceOracle,
            lpToken,
            lpContract,
            lowerBound,
            _calcUpperBound(lowerBound),
            updateBoundsAllowed,
            lastBoundsUpdate,
            priceFeed,
            stalenessPeriod,
            skipCheck
        );
    }
}
