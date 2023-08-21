// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {CONFIGURATOR} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {ERC4626PriceFeed} from "../../oracles/erc4626/ERC4626PriceFeed.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

// MOCKS
import {ERC4626Mock} from "../mocks/integrations/erc4626/ERC4626Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

// SUITES
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

// EXCEPTIONS
import {
    ZeroAddressException,
    ValueOutOfRangeException,
    IncorrectLimitsException,
    NotImplementedException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title ERC4626 price feed unit test
/// @notice U:[TVPF]: Unit tests for ERC4626 tokenized vault price feed
contract ERC4626PriceFeedUnitTest is Test {
// ERC4626PriceFeed vaultPriceFeed;

// ERC4626Mock vault;
// PriceFeedMock assetPriceFeed;
// AddressProviderV3ACLMock addressProvider;

// TokensTestSuite tokenTestSuite;

// function setUp() public {
//     vm.startPrank(CONFIGURATOR);

//     addressProvider = new AddressProviderV3ACLMock();
//     tokenTestSuite = new TokensTestSuite();

//     assetPriceFeed = new PriceFeedMock(1000, 8);
//     vm.label(address(assetPriceFeed), "DAI_PRICEFEED");

//     vault = new ERC4626Mock(tokenTestSuite.addressOf(Tokens.DAI), "Mock vault", "MOCK");
//     vm.label(address(vault), "ERC4626_MOCK");
//     vault.setAssetsPerShare(1 ether);

//     vaultPriceFeed = new ERC4626PriceFeed(address(addressProvider), address(vault), address(assetPriceFeed));
//     vm.label(address(vaultPriceFeed), "ERC4626_PRICE_FEED");

//     vm.stopPrank();
// }

// /// @notice U:[TVPF-1]: Constructor reverts on zero addresses
// function test_TVPF_01_constructor_reverts_for_zero_addresses() public {
//     vm.expectRevert(ZeroAddressException.selector);
//     new ERC4626PriceFeed(address(addressProvider), address(0), address(0));

//     vm.expectRevert(ZeroAddressException.selector);
//     new ERC4626PriceFeed(address(addressProvider), address(vault), address(0));
// }

// /// @notice U:[TVPF-2]: Constructor sets correct values
// function test_TVPF_02_constructor_sets_correct_values() public {
//     assertEq(vaultPriceFeed.description(), "Mock vault priceFeed", "Incorrect description");
//     assertEq(vaultPriceFeed.vault(), address(vault), "Incorrect vault");
//     assertEq(vaultPriceFeed.assetPriceFeed(), address(assetPriceFeed), "Incorrect assetPriceFeed");
//     assertEq(vaultPriceFeed.vaultShareUnit(), 10 ** 18, "Incorrect vaultShareUnit");
//     assertEq(vaultPriceFeed.underlyingUnit(), 10 ** 18, "Incorrect underlyingUnit");
//     assertEq(vaultPriceFeed.lowerBound(), 1 ether, "Incorrect lowerBound");
//     assertEq(vaultPriceFeed.upperBound(), 1.02 ether, "Incorrect upperBound");
// }

// /// @notice U:[TVPF-3]: `latestRoundData` reverts on incorrect asset price
// function test_TVPF_03_latestRoundData_reverts_on_incorrect_asset_price() public {
//     assetPriceFeed.setPrice(0);

//     vm.expectRevert(ZeroPriceException.selector);
//     vaultPriceFeed.latestRoundData();
// }

// struct LatestRoundDataTestCase {
//     string name;
//     // scenario
//     uint256 exchangeRate;
//     // outcome
//     bool mustRevert;
//     int256 expectedAnswer;
// }

// /// @notice U:[TVPF-4]: `latestRoundData` works as expected
// function test_TVPF_04_latestRoundData_works_as_expected() public {
//     LatestRoundDataTestCase[3] memory cases = [
//         LatestRoundDataTestCase({
//             name: "exchangeRate below lower bound",
//             exchangeRate: 0.99 ether,
//             mustRevert: true,
//             expectedAnswer: 0
//         }),
//         LatestRoundDataTestCase({
//             name: "exchangeRate within bounds",
//             exchangeRate: 1.01 ether,
//             mustRevert: false,
//             expectedAnswer: 1010 // 1.01 * 1000
//         }),
//         LatestRoundDataTestCase({
//             name: "exchangeRate above upper bound",
//             exchangeRate: 1.03 ether,
//             mustRevert: false,
//             expectedAnswer: 1020 // 1.02 * 1000 (not 1.03 * 1000)
//         })
//     ];

//     for (uint256 i; i < cases.length; ++i) {
//         vault.setAssetsPerShare(cases[i].exchangeRate);

//         if (cases[i].mustRevert) {
//             vm.expectRevert(ValueOutOfRangeException.selector);
//         }

//         (, int256 answer,,,) = vaultPriceFeed.latestRoundData();

//         if (!cases[i].mustRevert) {
//             assertEq(answer, cases[i].expectedAnswer, string.concat("Incorrect answer, case ", cases[i].name));
//         }
//     }
// }

// /// @notice U:[TVPF-5]: `setLimiter` reverts on exchange rate out of bounds
// function test_TVPF_05_setLimiter_reverts_on_exchange_rate_out_of_bounds() public {
//     vault.setAssetsPerShare(1.5 ether);

//     vm.expectRevert(IncorrectLimitsException.selector);
//     vm.prank(CONFIGURATOR);
//     vaultPriceFeed.setLimiter(1 ether);

//     vault.setAssetsPerShare(0.5 ether);

//     vm.expectRevert(IncorrectLimitsException.selector);
//     vm.prank(CONFIGURATOR);
//     vaultPriceFeed.setLimiter(1 ether);
// }
}
