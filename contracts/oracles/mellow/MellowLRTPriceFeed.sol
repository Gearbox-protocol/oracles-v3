// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMellowVault} from "../../interfaces/mellow/IMellowVault.sol";
import {SingleAssetLPPriceFeed} from "../SingleAssetLPPriceFeed.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Mellow LRT price feed
contract MellowLRTPriceFeed is SingleAssetLPPriceFeed {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PF_MELLOW_LRT_ORACLE";

    /// @dev Amount of base token comprising a single unit (accounting for decimals)
    uint256 immutable _baseTokenUnit;

    constructor(
        address _acl,
        uint256 lowerBound,
        address _vault,
        address _priceFeed,
        uint32 _stalenessPeriod,
        address baseToken
    )
        SingleAssetLPPriceFeed(_acl, _vault, _vault, _priceFeed, _stalenessPeriod) // U:[MEL-1]
    {
        _baseTokenUnit = 10 ** ERC20(baseToken).decimals();
        _setLimiter(lowerBound); // U:[MEL-1]
    }

    function getLPExchangeRate() public view override returns (uint256) {
        IMellowVault.ProcessWithdrawalsStack memory stack = IMellowVault(lpToken).calculateStack();
        return stack.totalValue * WAD / stack.totalSupply; // U:[MEL-1]
    }

    function getScale() public view override returns (uint256) {
        return _baseTokenUnit; // U:[MEL-1]
    }

    function serialize() external view returns (bytes memory) {
        return abi.encode(
            lpToken, lpContract, lowerBound, _calcUpperBound(lowerBound), priceFeed, stalenessPeriod, skipCheck
        );
    }
}
