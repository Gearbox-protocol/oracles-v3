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
    IBalancerStablePool public immutable balancerPool;

    /// @dev Price feed of asset 0 in the pool
    AggregatorV3Interface public immutable priceFeed0;

    /// @dev Price feed of asset 1 in the pool
    AggregatorV3Interface public immutable priceFeed1;

    /// @dev Price feed of asset 2 in the pool
    AggregatorV3Interface public immutable priceFeed2;

    /// @dev Price feed of asset 3 in the pool
    AggregatorV3Interface public immutable priceFeed3;

    /// @dev Price feed of asset 4 in the pool
    AggregatorV3Interface public immutable priceFeed4;

    uint8 public immutable numAssets;

    PriceFeedType public constant override priceFeedType = PriceFeedType.BALANCER_STABLE_LP_ORACLE;

    /// @dev Contract version
    uint256 public constant override version = 1;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(address addressProvider, address _balancerPool, uint8 _numAssets, address[] memory priceFeeds)
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _balancerPool != address(0) ? string(abi.encodePacked(IERC20Metadata(_balancerPool).name(), " priceFeed")) : ""
        )
    {
        if (_balancerPool == address(0)) revert ZeroAddressException(); // F: [OBSLP-2]

        uint256 len = priceFeeds.length;

        if (len != _numAssets) revert IncorrectPriceFeedException(); // F: [OBSLP-2]

        for (uint256 i = 0; i < len;) {
            if (priceFeeds[i] == address(0)) {
                revert ZeroAddressException(); // F: [OBSLP-2]
            }

            unchecked {
                ++i;
            }
        }

        numAssets = _numAssets; // F: [OBSLP-1]

        priceFeed0 = AggregatorV3Interface(priceFeeds[0]); // F: [OBSLP-1]
        priceFeed1 = AggregatorV3Interface(priceFeeds[1]); // F: [OBSLP-1]
        priceFeed2 = _numAssets >= 3 ? AggregatorV3Interface(priceFeeds[2]) : AggregatorV3Interface(address(0)); // F: [OBSLP-1]
        priceFeed3 = _numAssets >= 4 ? AggregatorV3Interface(priceFeeds[3]) : AggregatorV3Interface(address(0)); // F: [OBSLP-1]
        priceFeed4 = _numAssets == 5 ? AggregatorV3Interface(priceFeeds[4]) : AggregatorV3Interface(address(0)); // F: [OBSLP-1]

        balancerPool = IBalancerStablePool(_balancerPool); // F: [OBSLP-1]

        uint256 rate = balancerPool.getRate(); // F: [OBSLP-1]

        _setLimiter(rate); // F: [OBSLP-1]
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
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, answer,, updatedAt,) = priceFeed0.latestRoundData(); // F: [OBSLP-3]

        _checkAnswer(answer, updatedAt, 2 hours);

        int256 answerNext;
        uint256 updatedAtNext;

        (, answerNext,, updatedAtNext,) = priceFeed1.latestRoundData(); // F: [OBSLP-3]

        _checkAnswer(answerNext, updatedAtNext, 2 hours);

        if (answerNext < answer) {
            answer = answerNext;
            updatedAt = updatedAtNext;
        }

        if (numAssets >= 3) {
            (, answerNext,, updatedAtNext,) = priceFeed1.latestRoundData(); // F: [OBSLP-3]

            _checkAnswer(answerNext, updatedAtNext, 2 hours);

            if (answerNext < answer) {
                answer = answerNext;
                updatedAt = updatedAtNext;
            }
        }

        if (numAssets >= 4) {
            (, answerNext,, updatedAtNext,) = priceFeed1.latestRoundData(); // F: [OBSLP-3]

            _checkAnswer(answerNext, updatedAtNext, 2 hours);

            if (answerNext < answer) {
                answer = answerNext;
                updatedAt = updatedAtNext;
            }
        }

        if (numAssets == 5) {
            (, answerNext,, updatedAtNext,) = priceFeed1.latestRoundData(); // F: [OBSLP-3]

            _checkAnswer(answerNext, updatedAtNext, 2 hours);

            if (answerNext < answer) {
                answer = answerNext;
                updatedAt = updatedAtNext;
            }
        }

        uint256 rate = balancerPool.getRate(); // F: [OBSLP-3]

        // Checks that virtual_price is in within bounds
        rate = _checkAndUpperBoundValue(rate); // F: [OBSLP-3]

        answer = (answer * int256(rate)) / int256(DECIMALS); // F: [OBSLP-3]
    }

    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _upperBound)
        internal
        view
        override
        returns (bool)
    {
        uint256 rate = balancerPool.getRate();
        if (rate < _lowerBound || rate > _upperBound) {
            return false; // F: [OBSLP-4]
        }
        return true;
    }
}
