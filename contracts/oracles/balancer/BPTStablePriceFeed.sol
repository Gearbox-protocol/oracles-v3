// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {LPPriceFeed} from "../LPPriceFeed.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk/contracts/PriceFeedType.sol";

import {IBalancerStablePool} from "../../interfaces/balancer/IBalancerStablePool.sol";

// EXCEPTIONS
import {
    ZeroAddressException,
    IncorrectPriceFeedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%
uint256 constant DECIMALS = 10 ** 18;

/// @title BPT Stable pool LP price feed
contract BPTStablePriceFeed is LPPriceFeed {
    PriceFeedType public constant override priceFeedType = PriceFeedType.BALANCER_STABLE_LP_ORACLE;
    uint256 public constant override version = 3_00;
    bool public constant override skipPriceCheck = true;

    IBalancerStablePool public immutable balancerPool;

    /// @dev Price feed of asset 0 in the pool
    address public immutable priceFeed0;
    uint32 public immutable stalenessPeriod0;

    /// @dev Price feed of asset 1 in the pool
    address public immutable priceFeed1;
    uint32 public immutable stalenessPeriod1;

    /// @dev Price feed of asset 2 in the pool
    address public immutable priceFeed2;
    uint32 public immutable stalenessPeriod2;

    /// @dev Price feed of asset 3 in the pool
    address public immutable priceFeed3;
    uint32 public immutable stalenessPeriod3;

    /// @dev Price feed of asset 4 in the pool
    address public immutable priceFeed4;
    uint32 public immutable stalenessPeriod4;

    uint8 public immutable numAssets;

    constructor(
        address addressProvider,
        address _balancerPool,
        uint8 _numAssets,
        address[] memory priceFeeds,
        uint32[] memory stalenessPeriods
    )
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _balancerPool != address(0) ? string(abi.encodePacked(IERC20Metadata(_balancerPool).name(), " priceFeed")) : ""
        )
        nonZeroAddress(_balancerPool)
    {
        uint256 len = priceFeeds.length;
        if (len != _numAssets) revert IncorrectPriceFeedException(); // F: [OBSLP-2]

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                if (priceFeeds[i] == address(0)) {
                    revert ZeroAddressException(); // F: [OBSLP-2]
                }
            }
        }

        numAssets = _numAssets; // F: [OBSLP-1]

        priceFeed0 = priceFeeds[0]; // F: [OBSLP-1]
        priceFeed1 = priceFeeds[1]; // F: [OBSLP-1]
        priceFeed2 = _numAssets >= 3 ? priceFeeds[2] : address(0); // F: [OBSLP-1]
        priceFeed3 = _numAssets >= 4 ? priceFeeds[3] : address(0); // F: [OBSLP-1]
        priceFeed4 = _numAssets == 5 ? priceFeeds[4] : address(0); // F: [OBSLP-1]

        stalenessPeriod0 = stalenessPeriods[0]; // F: [OBSLP-1]
        stalenessPeriod1 = stalenessPeriods[1]; // F: [OBSLP-1]
        stalenessPeriod2 = _numAssets >= 3 ? stalenessPeriods[2] : 0; // F: [OBSLP-1]
        stalenessPeriod3 = _numAssets >= 4 ? stalenessPeriods[3] : 0; // F: [OBSLP-1]
        stalenessPeriod4 = _numAssets == 5 ? stalenessPeriods[4] : 0; // F: [OBSLP-1]

        balancerPool = IBalancerStablePool(_balancerPool); // F: [OBSLP-1]

        _setLimiter(_getContractValue()); // F: [OBSLP-1]
    }

    function _getContractValue() internal view override returns (uint256) {
        balancerPool.getRate();
    }

    /// @dev Returns the USD price of the pool's LP token
    /// @notice Computes the LP token price as (min_t(price(asset_t)) * getRate())
    ///         Same principle as Curve price feed is used since Balancer stable pools are essentially a copy of Curve stable pools
    ///         See more at https://dev.gearbox.fi/docs/documentation/oracle/curve-pricefeed
    function latestRoundData()
        external
        view
        virtual
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        (answer, updatedAt) = _getValidatedPrice(priceFeed0, stalenessPeriod0); // F:[OCLP-6]

        (int256 answerA, uint256 updatedAtA) = _getValidatedPrice(priceFeed1, stalenessPeriod1); // F:[OCLP-6]
        if (answerA < answer) {
            answer = answerA;
            updatedAt = updatedAtA;
        } // F:[OCLP-6]

        if (numAssets >= 3) {
            (answerA, updatedAtA) = _getValidatedPrice(priceFeed1, stalenessPeriod1); // F:[OCLP-6]
            if (answerA < answer) {
                answer = answerA;
                updatedAt = updatedAtA;
            } // F:[OCLP-6]

            if (numAssets >= 4) {
                (answerA, updatedAtA) = _getValidatedPrice(priceFeed1, stalenessPeriod1); // F:[OCLP-6]
                if (answerA < answer) {
                    answer = answerA;
                    updatedAt = updatedAtA;
                } // F:[OCLP-6]

                if (numAssets == 5) {
                    (answerA, updatedAtA) = _getValidatedPrice(priceFeed1, stalenessPeriod1); // F:[OCLP-6]
                    if (answerA < answer) {
                        answer = answerA;
                        updatedAt = updatedAtA;
                    } // F:[OCLP-6]
                }
            }
        }

        // Checks that virtual_price is in within bounds
        uint256 rate = _getValidatedContractValue(); // F: [OBSLP-3]
        answer = (answer * int256(rate)) / int256(DECIMALS); // F: [OBSLP-3]
    }
}
