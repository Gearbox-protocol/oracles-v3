// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedType} from "../../interfaces/IPriceFeedType.sol";
import {LPPriceFeed} from "../LPPriceFeed.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

uint256 constant RANGE_WIDTH = 200;

/// @title ERC4626 vault shares price feed
contract ERC4626PriceFeed is LPPriceFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.ERC4626_VAULT_ORACLE;
    uint256 public constant override version = 1;

    /// @notice Vault to compute prices for
    address public immutable vault;

    /// @notice Vault's underlying asset price feed
    address public immutable assetPriceFeed;

    /// @notice Amount of shares comprising a single unit (accounting for decimals)
    uint256 public immutable vaultShareUnit;

    /// @notice Amount of underlying comprising a single unit (accounting for decimals)
    uint256 public immutable underlyingUnit;

    /// @notice Whether to skip price sanity checks (always true for LP price feeds which perform their own checks)
    bool public constant override skipPriceCheck = true;

    /// @notice Constructor
    /// @param addressProvider Address provider contract
    /// @param _vault Vault to compute prices for
    /// @param _assetPriceFeed Vault's underlying asset price feed
    constructor(address addressProvider, address _vault, address _assetPriceFeed)
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _vault != address(0) ? string(abi.encodePacked(ERC20(_vault).name(), " priceFeed")) : ""
        ) // U:[TVPF-2]
        nonZeroAddress(_vault) // U:[TVPF-1]
        nonZeroAddress(_assetPriceFeed) // U:[TVPF-1]
    {
        vault = _vault; // U:[TVPF-2]
        assetPriceFeed = _assetPriceFeed; // U:[TVPF-2]

        vaultShareUnit = 10 ** IERC4626(_vault).decimals(); // U:[TVPF-2]
        underlyingUnit = 10 ** ERC20(IERC4626(_vault).asset()).decimals(); // U:[TVPF-2]

        _setLimiter(IERC4626(_vault).convertToAssets(vaultShareUnit)); // U:[TVPF-2]
    }

    /// @notice Returns the USD price of a single pool share
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) =
            AggregatorV3Interface(assetPriceFeed).latestRoundData(); // U:[TVPF-3,4]

        _checkAnswer(answer, updatedAt, 2 hours); // U:[TVPF-3]

        uint256 assetsPerShare = IERC4626(vault).convertToAssets(vaultShareUnit); // U:[TVPF-4]

        assetsPerShare = _checkAndUpperBoundValue(assetsPerShare); // U:[TVPF-4]

        answer = int256((assetsPerShare * uint256(answer)) / underlyingUnit); // U:[TVPF-4]
    }

    /// @dev Returns true if assets per share falls within bounds and false otherwise
    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _upperBound)
        internal
        view
        override
        returns (bool)
    {
        uint256 assetsPerShare = IERC4626(vault).convertToAssets(vaultShareUnit); // U:[TVPF-5]
        return assetsPerShare >= _lowerBound && assetsPerShare <= _upperBound; // U:[TVPF-5]
    }
}
