// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IncorrectPriceException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Constant price feed
/// @notice A simple price feed that returns a constant value set in the constructor
contract ConstantPriceFeed is IPriceFeed, SanityCheckTrait {
    /// @notice Contract version
    uint256 public constant override version = 3_10;

    /// @notice Contract type
    bytes32 public constant override contractType = "PRICE_FEED::CONSTANT";

    /// @notice Answer precision (always 8 decimals for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice Indicates that price oracle can skip checks for this price feed's answers
    bool public constant override skipPriceCheck = true;

    /// @notice The token address this price feed is for
    address public immutable token;

    /// @notice The constant price value to return
    int256 public immutable price;

    /// @notice Price feed description
    string public description;

    /// @notice Constructor
    /// @param _token The token address this price feed is for
    /// @param _price The constant price value to return (with 8 decimals)
    constructor(address _token, int256 _price) nonZeroAddress(_token) {
        if (_price <= 0) revert IncorrectPriceException();

        token = _token;
        price = _price;

        string memory tokenSymbol = IERC20Metadata(_token).symbol();
        description = string.concat(tokenSymbol, " / USD constant price feed");
    }

    /// @notice Serialized price feed parameters
    function serialize() external view override returns (bytes memory) {
        return abi.encode(token, price);
    }

    /// @notice Returns the constant USD price of the token with 8 decimals
    function latestRoundData() external view override returns (uint80, int256 answer, uint256, uint256, uint80) {
        return (0, price, 0, block.timestamp, 0);
    }
}
