// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeed.sol";
import {IBalancerWeightedPool} from "../../../interfaces/balancer/IBalancerWeightedPool.sol";
import {IBalancerVault} from "../../../interfaces/balancer/IBalancerVault.sol";

import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {SupportedContracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import {TokenType} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Tokens, TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {NetworkDetector} from "@gearbox-protocol/sdk-gov/contracts/NetworkDetector.sol";
import {PriceFeedType} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {PriceFeedDeployer} from "../../suites/PriceFeedDeployer.sol";

import {Test} from "forge-std/Test.sol";

contract BPTStablePriceFeed is Test {
    PriceFeedDeployer public pfd;
    uint256 chainId;

    modifier liveTestOnly() {
        if (chainId != 1337 && chainId != 31337) {
            _;
        }
    }

    function setUp() public {
        NetworkDetector nd = new NetworkDetector();
        chainId = nd.chainId();

        if (chainId != 1337 && chainId != 31337) {
            TokensTestSuite tokenTestSuite = new TokensTestSuite();

            AddressProviderV3ACLMock addressProvider = new AddressProviderV3ACLMock();
            SupportedContracts sc = new SupportedContracts(chainId);

            pfd = new PriceFeedDeployer(chainId, address(addressProvider), tokenTestSuite, sc);
        }
    }

    function test_live_BAL_EQ_01_Balancer_BPT_stable_pf_returns_price_equal_or_lower() public liveTestOnly {
        uint256 len = pfd.priceFeedConfigLength();

        for (uint256 i; i < len; ++i) {
            (address token, address priceFeed,,) = pfd.priceFeedConfig(i);

            PriceFeedType pft;

            try IPriceFeed(priceFeed).priceFeedType() returns (PriceFeedType _pft) {
                pft = _pft;
            } catch {
                pft = PriceFeedType.CHAINLINK_ORACLE;
            }

            if (
                pft != PriceFeedType.BALANCER_STABLE_LP_ORACLE
                    || pfd.tokenTestSuite().tokenTypes(pfd.tokenTestSuite().tokenIndexes(token))
                        != TokenType.BALANCER_LP_TOKEN
            ) continue;

            (, int256 pfPrice,,,) = IPriceFeed(priceFeed).latestRoundData();

            bytes32 poolId = IBalancerWeightedPool(token).getPoolId();
            address vault = IBalancerWeightedPool(token).getVault();

            (address[] memory tokens, uint256[] memory balances,) = IBalancerVault(vault).getPoolTokens(poolId);

            int256 computedPrice = 0;

            for (uint256 j = 0; j < tokens.length; ++j) {
                if (tokens[j] == token) continue;

                (, int256 assetPrice,,,) = IPriceFeed(pfd.priceFeeds(tokens[j])).latestRoundData();

                computedPrice += assetPrice * int256(balances[j]) / int256(10 ** ERC20(tokens[j]).decimals());
            }

            uint256 supply;

            try IBalancerWeightedPool(token).getActualSupply() returns (uint256 _supply) {
                supply = _supply;
            } catch {
                supply = ERC20(token).totalSupply();
            }

            computedPrice = computedPrice * 1e18 / int256(supply);

            assertLe(pfPrice, computedPrice, "PF price higher than computed based on value of pool assets");
        }
    }
}
