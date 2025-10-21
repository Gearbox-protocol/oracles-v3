// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IKodiakIsland} from "../../interfaces/kodiak/IKodiakIsland.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {PriceFeedValidationTrait} from "../../traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Kodiak Island price feed
/// @notice Computes the price of the Kodiak Island LP token
contract KodiakIslandPriceFeed is IPriceFeed, PriceFeedValidationTrait, SanityCheckTrait {
    using LibString for string;
    using LibString for bytes32;

    uint256 public constant SQRT_RATIO_PRECISION = 2 ** 96;

    uint256 public constant SQRT_WAD = 10 ** 9;

    /// @notice Contract version
    uint256 public constant override version = 3_11;

    /// @notice Contract type
    bytes32 public constant override contractType = "PRICE_FEED::KODIAK_ISLAND";

    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true;

    /// @notice Kodiak Island address
    address public immutable kodiakIsland;

    /// @notice Price feed for the first asset
    address public immutable priceFeed0;

    /// @notice Price feed for the second asset
    address public immutable priceFeed1;

    /// @notice Staleness period for the first asset
    uint32 public immutable stalenessPeriod0;

    /// @notice Staleness period for the second asset
    uint32 public immutable stalenessPeriod1;

    /// @notice Flag indicating if price feed 0 checks can be skipped
    bool public immutable skipCheck0;

    /// @notice Flag indicating if price feed 1 checks can be skipped
    bool public immutable skipCheck1;

    /// @notice Decimals for the first asset
    uint256 public immutable decimalsMultiplier0;

    /// @notice Decimals for the second asset
    uint256 public immutable decimalsMultiplier1;

    /// @dev Short form description
    bytes32 internal descriptionTicker;

    /// @notice Constructor
    /// @param _kodiakIsland Address of the Kodiak Island
    /// @param _priceFeed0 Address of the first asset price feed
    /// @param _priceFeed1 Address of the second asset price feed
    /// @param _stalenessPeriod0 Staleness period for the first asset price feed
    /// @param _stalenessPeriod1 Staleness period for the second asset price feed
    /// @param _descriptionTicker Short form description
    constructor(
        address _kodiakIsland,
        address _priceFeed0,
        address _priceFeed1,
        uint32 _stalenessPeriod0,
        uint32 _stalenessPeriod1,
        string memory _descriptionTicker
    ) nonZeroAddress(_kodiakIsland) nonZeroAddress(_priceFeed0) nonZeroAddress(_priceFeed1) {
        kodiakIsland = _kodiakIsland;
        priceFeed0 = _priceFeed0;
        priceFeed1 = _priceFeed1;
        stalenessPeriod0 = _stalenessPeriod0;
        stalenessPeriod1 = _stalenessPeriod1;
        skipCheck0 = _validatePriceFeedMetadata(_priceFeed0, _stalenessPeriod0);
        skipCheck1 = _validatePriceFeedMetadata(_priceFeed1, _stalenessPeriod1);
        descriptionTicker = _descriptionTicker.toSmallString();

        address token0 = IKodiakIsland(kodiakIsland).token0();
        address token1 = IKodiakIsland(kodiakIsland).token1();

        decimalsMultiplier0 = 10 ** IERC20Metadata(token0).decimals();
        decimalsMultiplier1 = 10 ** IERC20Metadata(token1).decimals();
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(descriptionTicker.fromSmallString(), " Kodiak Island price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() external view override returns (bytes memory) {
        return abi.encode(
            kodiakIsland,
            priceFeed0,
            priceFeed1,
            stalenessPeriod0,
            stalenessPeriod1,
            decimalsMultiplier0,
            decimalsMultiplier1
        );
    }

    /// @dev Returns the square root of the price ratio in UniswapV3 format
    function _getSqrtPriceRatioX96(int256 price0, int256 price1) internal view returns (uint160 sqrtPriceRatioX96) {
        uint256 priceRatio = (uint256(price0) * decimalsMultiplier1 * WAD) / (uint256(price1) * decimalsMultiplier0);
        return uint160(Math.sqrt(priceRatio) * SQRT_RATIO_PRECISION / SQRT_WAD);
    }

    /// @dev Returns Island asset balances normalized to 18 decimals
    function _getNormalizedBalances(uint160 sqrtPriceRatioX96)
        internal
        view
        returns (uint256 balance0, uint256 balance1)
    {
        (balance0, balance1) = IKodiakIsland(kodiakIsland).getUnderlyingBalancesAtPrice(sqrtPriceRatioX96);

        balance0 = balance0 * WAD / decimalsMultiplier0;
        balance1 = balance1 * WAD / decimalsMultiplier1;
    }

    /// @notice Returns USD price of the token token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        (int256 price0, uint256 updatedAt0) = _getValidatedPrice(priceFeed0, stalenessPeriod0, skipCheck0);
        (int256 price1, uint256 updatedAt1) = _getValidatedPrice(priceFeed1, stalenessPeriod1, skipCheck1);

        uint160 sqrtPriceRatioX96 = _getSqrtPriceRatioX96(price0, price1);
        (uint256 balance0, uint256 balance1) = _getNormalizedBalances(sqrtPriceRatioX96);

        int256 totalValue = int256(balance0) * price0 + int256(balance1) * price1;

        uint256 totalSupply = IKodiakIsland(kodiakIsland).totalSupply();

        int256 answer = totalValue / int256(totalSupply);
        uint256 updatedAt = Math.min(updatedAt0, updatedAt1);
        return (0, answer, 0, updatedAt, 0);
    }
}
