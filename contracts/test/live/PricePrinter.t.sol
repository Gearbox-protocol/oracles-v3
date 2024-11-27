// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";

import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {SupportedContracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {NetworkDetector} from "@gearbox-protocol/sdk-gov/contracts/NetworkDetector.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {PriceFeedDeployer} from "../suites/PriceFeedDeployer.sol";

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract PricePrinterTest is Test {
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
            pfd.updateRedstoneOraclePriceFeeds();
        }
    }

    function test_print_all_prices() public liveTestOnly {
        emit log_string("MAIN FEEDS");
        emit log_string("");

        uint256 len = pfd.priceFeedConfigLength();

        bool mustFail;
        emit log_string(string.concat("Found ", vm.toString(len), " tokens"));
        for (uint256 i; i < len; ++i) {
            (address token, address priceFeed,) = pfd.priceFeedConfig(i);
            uint256 t = pfd.tokenTestSuite().tokenIndexes(token);

            emit log_string(pfd.tokenTestSuite().symbols(t));
            emit log_named_string("    Price feed", IPriceFeed(priceFeed).description());
            try IPriceFeed(priceFeed).latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
                emit log_named_decimal_int("    Price", price, 8);
            } catch {
                emit log_string("    Price: REVERT");
                mustFail = true;
            }
        }

        emit log_string("");
        emit log_string("RESERVE FEEDS");
        emit log_string("");

        len = pfd.priceFeedConfigReserveLength();

        emit log_string(string.concat("Found ", vm.toString(len), " tokens"));
        for (uint256 i; i < len; ++i) {
            (address token, address priceFeed,) = pfd.priceFeedConfigReserve(i);
            uint256 t = pfd.tokenTestSuite().tokenIndexes(token);

            emit log_string(pfd.tokenTestSuite().symbols(t));
            emit log_named_string("    Price feed", IPriceFeed(priceFeed).description());
            try IPriceFeed(priceFeed).latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
                emit log_named_decimal_int("    Price", price, 8);
            } catch {
                emit log_string("    Price: REVERT");
                mustFail = true;
            }
        }

        if (mustFail) fail();
    }
}
