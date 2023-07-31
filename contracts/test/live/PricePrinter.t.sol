// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {SupportedContracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";
import {Tokens, TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {NetworkDetector} from "@gearbox-protocol/sdk/contracts/NetworkDetector.sol";

import {PriceFeedConfig, PriceFeedDeployer} from "../suites/PriceFeedDeployer.sol";

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
        }
    }

    function printUsdPrice(address token, uint256 price) public view {
        uint256 integerPart = price / 1e8;
        uint256 fractionalPart = (price / 1e6) % 100;
        string memory result = string.concat(
            ERC20(token).symbol(), ": $", Strings.toString(integerPart), ".", Strings.toString(fractionalPart)
        );
        console.log(result);
    }

    function test_print_all_prices() public liveTestOnly {
        uint256 len = pfd.priceFeedConfigLength();

        console.log("Found: ", len, " tokens");
        for (uint256 i; i < len; ++i) {
            (address token, address priceFeed) = pfd.priceFeedConfig(i);

            (, int256 price,,,) = AggregatorV3Interface(priceFeed).latestRoundData();

            printUsdPrice(token, uint256(price));
        }
    }
}
