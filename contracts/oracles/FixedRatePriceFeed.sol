// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IFixedRatePriceFeed} from "../interfaces/IFixedRatePriceFeed.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Fixed rate price feed
/// @notice A price feed that multiplies the price of the LP token by a fixed rate set by the owner
/// @dev Only recommended for use as a reserve price feed
contract FixedRatePriceFeed is Ownable, PriceFeedValidationTrait, SanityCheckTrait, IFixedRatePriceFeed {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PRICE_FEED::FIXED_RATE";

    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true;

    /// @notice LP token for which the prices are computed
    address public immutable lpToken;

    /// @dev Price feed's address
    address public immutable priceFeed;

    /// @dev Price feed's staleness period
    uint32 public immutable stalenessPeriod;

    /// @dev Price feed's skip check
    bool public immutable skipCheck;

    /// @dev Scale of price feed's rate
    uint256 public immutable scale;

    /// @dev The rate of the LP token
    uint256 public rate;

    constructor(
        address _owner,
        uint256 _initialRate,
        uint256 _rateScale,
        address _priceFeed,
        uint32 _stalenessPeriod,
        address _lpToken
    ) nonZeroAddress(_priceFeed) nonZeroAddress(_lpToken) {
        _transferOwnership(_owner);
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        skipCheck = _validatePriceFeedMetadata(_priceFeed, _stalenessPeriod);
        rate = _initialRate;
        scale = _rateScale;
        lpToken = _lpToken;
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(ERC20(lpToken).symbol(), " / USD LP fixed rate price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() public view virtual override returns (bytes memory) {
        return abi.encode(lpToken, rate, priceFeed);
    }

    /// @notice Returns USD price of the LP token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck) * int256(rate) / int256(scale);
        return (0, answer, 0, 0, 0);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets the new rate for the LP token
    /// @param newRate New rate
    function setRate(uint256 newRate) external override onlyOwner {
        if (newRate == 0) revert RateCantBeZeroException();
        if (rate == newRate) return;
        rate = newRate;
        emit SetRate(newRate);
    }
}
