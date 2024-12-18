// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {WAD, SECONDS_PER_YEAR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

import {IPriceFeed} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeed.sol";
import {IPendleMarket} from "../../interfaces/pendle/IPendleMarket.sol";
import {IPendleYT, IPendleSY} from "../../interfaces/pendle/IPendleTokens.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {PriceFeedParams} from "../PriceFeedParams.sol";
import {FixedPoint} from "../../libraries/FixedPoint.sol";
import {LogExpMath} from "../../libraries/LogExpMath.sol";

/// @title Pendle PT price feed based on Pendle market TWAPs
/// @notice The PT price is derived from the Pendle market's ln(impliedRate) TWAP:
///         1) The average implied rate is computed as (ln(IR)_(now) - ln(IR)_(now - timeWindow)) / timeWindow;
///         2) The PT to asset rate is computed as 1 / (e ^ (ln(IR)_avg * timeToExpiry / secondsPerYear));
///         3) The PT price is ptToAssetRate * assetPrice;
contract PendleTWAPPTPriceFeed is IPriceFeed, PriceFeedValidationTrait, SanityCheckTrait {
    uint256 public constant override version = 3_00;
    PriceFeedType public constant override priceFeedType = PriceFeedType.PENDLE_PT_TWAP_ORACLE;
    uint8 public constant override decimals = 8;
    string public description;

    /// @notice Indicates whether the consuming PriceOracle can skip the sanity checks. Set to `true`
    ///         since this price feed performs sanity checks locally
    bool public constant override skipPriceCheck = true;

    /// @notice Address of the pendle market where the PT is traded
    address public immutable market;

    /// @notice Address of the Pendle SY connected to the PT
    address public immutable sy;

    /// @notice Address of the Pendle YT connected to the YT
    address public immutable yt;

    /// @notice Timestamp of the market (and PT) expiry
    uint256 public immutable expiry;

    /// @notice Underlying price feed
    address public immutable priceFeed;
    uint32 public immutable stalenessPeriod;
    bool public immutable skipCheck;

    /// @notice The size of the TWAP observation window
    uint32 public immutable twapWindow;

    /// @notice Whether this price feed prices to SY
    bool public immutable priceToSy;

    constructor(address _market, address _priceFeed, uint32 _stalenessPeriod, uint32 _twapWindow, bool _priceToSY) {
        market = _market;
        expiry = IPendleMarket(_market).expiry();
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        skipCheck = _validatePriceFeed(priceFeed, stalenessPeriod);
        twapWindow = _twapWindow;
        priceToSy = _priceToSY;

        address pt;

        (sy, pt, yt) = IPendleMarket(_market).readTokens();

        string memory ptName = IERC20Metadata(pt).name();

        description = string(
            abi.encodePacked(
                ptName,
                " Pendle Market TWAP ",
                priceToSy ? "to SY" : "to asset",
                " * ",
                IPriceFeed(priceFeed).description()
            )
        );
    }

    /// @dev Gets the ln(impliedRate) from the market TWAP
    function _getMarketLnImpliedRate() internal view returns (uint256) {
        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[1] = twapWindow;

        uint216[] memory cumulativeLIR = IPendleMarket(market).observe(secondAgos);

        return (cumulativeLIR[0] - cumulativeLIR[1]) / twapWindow;
    }

    /// @dev Computes the PT to asset rate from the market implied rate TWAP
    function _getPTToAssetRate() internal view returns (uint256) {
        uint256 assetToPTRate =
            uint256(LogExpMath.exp(int256(_getMarketLnImpliedRate() * (expiry - block.timestamp) / SECONDS_PER_YEAR)));

        return FixedPoint.divDown(WAD, assetToPTRate);
    }

    /// @dev Retrieves the current SY and YT indices
    function _getSYandPYIndex() internal view returns (uint256 syIndex, uint256 pyIndex) {
        syIndex = IPendleSY(sy).exchangeRate();
        uint256 pyIndexStored = IPendleYT(yt).pyIndexStored();

        if (IPendleYT(yt).doCacheIndexSameBlock() && IPendleYT(yt).pyIndexLastUpdatedBlock() == block.number) {
            pyIndex = pyIndexStored;
        } else {
            pyIndex = syIndex >= pyIndexStored ? syIndex : pyIndexStored;
        }
    }

    /// @notice Returns the USD price of the PT token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        int256 answer = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck);

        if (expiry > block.timestamp) {
            answer = int256(FixedPoint.mulDown(uint256(answer), _getPTToAssetRate()));
        }

        (uint256 syIndex, uint256 pyIndex) = _getSYandPYIndex();

        if (syIndex < pyIndex) {
            answer = int256(uint256(answer) * syIndex / pyIndex);
        }

        if (priceToSy) {
            answer = int256(FixedPoint.divDown(uint256(answer), syIndex));
        }

        return (0, answer, 0, 0, 0);
    }
}
