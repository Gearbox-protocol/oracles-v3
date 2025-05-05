// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IFixedMultiplierPriceFeed} from "../interfaces/IFixedMultiplierPriceFeed.sol";
import {PriceFeedValidationTrait} from "@gearbox-protocol/core-v3/contracts/traits/PriceFeedValidationTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Fixed multiplier price feed
/// @notice A price feed that multiplies the price of the LP token by a fixed multiplier set by the owner
/// @dev Only recommended for use as a reserve price feed
contract FixedMultiplierPriceFeed is Ownable, PriceFeedValidationTrait, SanityCheckTrait, IFixedMultiplierPriceFeed {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PRICE_FEED::FIXED_MULTIPLIER";

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

    /// @dev Scale of price feed's multiplier
    uint256 public immutable scale;

    /// @dev The multiplier of the LP token
    uint256 public multiplier;

    constructor(
        address _owner,
        uint256 _initialMultiplier,
        uint256 _multiplierScale,
        address _priceFeed,
        uint32 _stalenessPeriod,
        address _lpToken
    ) nonZeroAddress(_priceFeed) nonZeroAddress(_lpToken) {
        _transferOwnership(_owner);
        priceFeed = _priceFeed;
        stalenessPeriod = _stalenessPeriod;
        skipCheck = _validatePriceFeedMetadata(_priceFeed, _stalenessPeriod);
        multiplier = _initialMultiplier;
        scale = _multiplierScale;
        lpToken = _lpToken;
    }

    /// @notice Price feed description
    function description() external view override returns (string memory) {
        return string.concat(ERC20(lpToken).symbol(), " / USD LP fixed multiplier price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() public view virtual override returns (bytes memory) {
        return abi.encode(lpToken, multiplier, priceFeed);
    }

    /// @notice Returns USD price of the LP token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = _getValidatedPrice(priceFeed, stalenessPeriod, skipCheck) * int256(multiplier) / int256(scale);
        return (0, answer, 0, 0, 0);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets the new multiplier for the LP token
    /// @param newMultiplier New multiplier
    function setMultiplier(uint256 newMultiplier) external override onlyOwner {
        if (newMultiplier == 0) revert MultiplierCantBeZeroException();
        if (multiplier == newMultiplier) return;
        multiplier = newMultiplier;
        emit SetMultiplier(newMultiplier);
    }
}
