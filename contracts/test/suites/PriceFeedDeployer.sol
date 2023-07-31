// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test} from "forge-std/Test.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {ISupportedContracts, Contracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";
import {
    PriceFeedDataLive,
    ChainlinkPriceFeedData,
    BoundedPriceFeedData,
    SingeTokenPriceFeedData,
    CompositePriceFeedData,
    CurvePriceFeedData,
    GenericLPPriceFeedData,
    TheSamePriceFeedData,
    RedStonePriceFeedData
} from "@gearbox-protocol/sdk/contracts/PriceFeedDataLive.sol";

import {PriceFeedConfig} from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracleV2.sol";
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

import {ZeroPriceFeed} from "../../oracles/ZeroPriceFeed.sol";
import {YearnPriceFeed} from "../../oracles/yearn/YearnPriceFeed.sol";
import {WstETHPriceFeed} from "../../oracles/lido/WstETHPriceFeed.sol";
import {CompositePriceFeed} from "../../oracles/CompositePriceFeed.sol";
import {BoundedPriceFeed} from "../../oracles/BoundedPriceFeed.sol";

import {CurveLP2PriceFeed} from "../../oracles/curve/CurveLP2PriceFeed.sol";
import {CurveLP3PriceFeed} from "../../oracles/curve/CurveLP3PriceFeed.sol";
import {CurveLP4PriceFeed} from "../../oracles/curve/CurveLP4PriceFeed.sol";
import {CurveCryptoLPPriceFeed} from "../../oracles/curve/CurveCryptoLPPriceFeed.sol";

import {WrappedAaveV2PriceFeed} from "../../oracles/aave/WrappedAaveV2PriceFeed.sol";
import {CompoundV2PriceFeed} from "../../oracles/compound/CompoundV2PriceFeed.sol";
import {ERC4626PriceFeed} from "../../oracles/erc4626/ERC4626PriceFeed.sol";
import {RedstonePriceFeed} from "../../oracles/redstone/RedstonePriceFeed.sol";

import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {IstETHPoolGateway} from "../../interfaces/curve/IstETHPoolGateway.sol";

import "forge-std/console.sol";

contract PriceFeedDeployer is Test, PriceFeedDataLive {
    TokensTestSuite public tokenTestSuite;
    mapping(address => address) public priceFeeds;
    PriceFeedConfig[] public priceFeedConfig;
    uint256 public priceFeedConfigLength;

    constructor(
        uint16 networkId,
        address addressProvider,
        TokensTestSuite _tokenTestSuite,
        ISupportedContracts supportedContracts
    ) PriceFeedDataLive(networkId) {
        tokenTestSuite = _tokenTestSuite;
        // CHAINLINK PRICE FEEDS
        ChainlinkPriceFeedData[] memory chainlinkPriceFeeds = chainlinkPriceFeedsByNetwork[networkId];
        uint256 len = chainlinkPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pf = chainlinkPriceFeeds[i].priceFeed;
                Tokens t = chainlinkPriceFeeds[i].token;

                address token = tokenTestSuite.addressOf(t);

                if (token != address(0) && pf != address(0)) {
                    setPriceFeed(token, pf);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }
        {
            // BOUNDED_PRICE_FEEDS
            BoundedPriceFeedData[] memory boundedPriceFeeds = boundedPriceFeedsByNetwork[networkId];
            len = boundedPriceFeeds.length;
            unchecked {
                for (uint256 i = 0; i < len; ++i) {
                    Tokens t = boundedPriceFeeds[i].token;

                    address token = tokenTestSuite.addressOf(t);

                    if (token != address(0)) {
                        address pf = address(
                            new BoundedPriceFeed(
                            boundedPriceFeeds[i].priceFeed,
                            int256(boundedPriceFeeds[i].upperBound)
                            )
                        );

                        setPriceFeed(token, pf);

                        string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                        vm.label(pf, description);
                    }
                }
            }
        }
        {
            // COMPOSITE_PRICE_FEEDS
            CompositePriceFeedData[] memory compositePriceFeeds = compositePriceFeedsByNetwork[networkId];
            len = compositePriceFeeds.length;
            unchecked {
                for (uint256 i = 0; i < len; ++i) {
                    Tokens t = compositePriceFeeds[i].token;

                    address token = tokenTestSuite.addressOf(t);

                    if (
                        token != address(0) && compositePriceFeeds[i].targetToBaseFeed != address(0)
                            && compositePriceFeeds[i].baseToUSDFeed != address(0)
                    ) {
                        address pf = address(
                            new CompositePriceFeed(
                            compositePriceFeeds[i].targetToBaseFeed,
                            compositePriceFeeds[i].baseToUSDFeed
                            )
                        );

                        setPriceFeed(token, pf);

                        string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                        vm.label(pf, description);
                    }
                }
            }
        }
        // ZERO PRICE FEEDS
        {
            SingeTokenPriceFeedData[] memory zeroPriceFeeds = zeroPriceFeedsByNetwork[networkId];
            len = zeroPriceFeeds.length;
            if (len > 0) {
                address zeroPF = address(new ZeroPriceFeed());
                unchecked {
                    for (uint256 i; i < len; ++i) {
                        address token = tokenTestSuite.addressOf(zeroPriceFeeds[i].token);
                        if (token != address(0)) {
                            setPriceFeed(token, zeroPF);

                            vm.label(zeroPF, "ZERO PRICEFEED");
                        }
                    }
                }
            }
        }

        // CURVE PRICE FEEDS
        {
            CurvePriceFeedData[] memory curvePriceFeeds = curvePriceFeedsByNetwork[networkId];
            len = curvePriceFeeds.length;

            unchecked {
                for (uint256 i; i < len; ++i) {
                    Tokens lpToken = curvePriceFeeds[i].lpToken;

                    uint256 nCoins = curvePriceFeeds[i].assets.length;
                    address pf;

                    address pool = supportedContracts.addressOf(curvePriceFeeds[i].pool);

                    address asset0 = tokenTestSuite.addressOf(curvePriceFeeds[i].assets[0]);
                    address asset1 = tokenTestSuite.addressOf(curvePriceFeeds[i].assets[1]);
                    address asset2 = nCoins > 2 ? tokenTestSuite.addressOf(curvePriceFeeds[i].assets[2]) : address(0);
                    address asset3 = nCoins > 3 ? tokenTestSuite.addressOf(curvePriceFeeds[i].assets[3]) : address(0);

                    if (
                        pool != address(0) && tokenTestSuite.addressOf(lpToken) != address(0) && asset0 != address(0)
                            && asset1 != address(0)
                    ) {
                        if (curvePriceFeeds[i].pool == Contracts.CURVE_STETH_GATEWAY) {
                            pool = IstETHPoolGateway(pool).pool();
                        }

                        string memory description =
                            string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken)));

                        if (nCoins == 2) {
                            pf = address(
                                new CurveLP2PriceFeed(
                                addressProvider,
                                pool,
                                priceFeeds[
                                asset0
                                ],
                                priceFeeds[
                                asset1
                                ],
                                description
                                )
                            );
                        } else if (nCoins == 3 && asset2 != address(0)) {
                            pf = address(
                                new CurveLP3PriceFeed(
                                addressProvider,
                                pool,
                                priceFeeds[
                                asset0
                                ],
                                priceFeeds[
                                asset1
                                ],
                                priceFeeds[
                                asset2
                                ],
                                description
                                )
                            );
                        } else if (nCoins == 4 && asset2 != address(0) && asset3 != address(0)) {
                            pf = address(
                                new CurveLP4PriceFeed(
                                addressProvider,
                                pool,
                                priceFeeds[
                                asset0
                                ],
                                priceFeeds[
                                asset1
                                ],
                                priceFeeds[
                                asset2
                                ],
                                priceFeeds[
                                asset3
                                ],
                                description
                                )
                            );
                        }

                        setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                        vm.label(pf, description);
                    }
                }
            }
        }

        // CURVE CRYPTO PRICE FEEDS
        CurvePriceFeedData[] memory curveCryptoPriceFeeds = curveCryptoPriceFeedsByNetwork[networkId];
        len = curveCryptoPriceFeeds.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens lpToken = curveCryptoPriceFeeds[i].lpToken;
                uint256 nCoins = curveCryptoPriceFeeds[i].assets.length;
                address pf;

                address pool = supportedContracts.addressOf(curveCryptoPriceFeeds[i].pool);

                if (pool != address(0) && tokenTestSuite.addressOf(lpToken) != address(0)) {
                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken)));

                    pf = address(
                        new CurveCryptoLPPriceFeed(
                            addressProvider,
                            pool,
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curveCryptoPriceFeeds[i].assets[0]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curveCryptoPriceFeeds[i].assets[1]
                                )
                            ],
                            nCoins == 3 ? priceFeeds[
                                tokenTestSuite.addressOf(
                                    curveCryptoPriceFeeds[i].assets[2]
                                )
                            ] : address(0),
                            description
                        )
                    );

                    setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                    vm.label(pf, description);
                }
            }
        }

        // CURVE LIKE PRICEFEEDS
        TheSamePriceFeedData[] memory theSamePriceFeeds = theSamePriceFeedsByNetwork[networkId];
        len = theSamePriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address token = tokenTestSuite.addressOf(theSamePriceFeeds[i].token);

                if (token != address(0)) {
                    address tokenHasSamePriceFeed = tokenTestSuite.addressOf(theSamePriceFeeds[i].tokenHasSamePriceFeed);
                    address pf = priceFeeds[tokenHasSamePriceFeed];
                    if (pf != address(0)) {
                        setPriceFeed(token, pf);
                    } else {
                        console.log("WARNING: Price feed for ", ERC20(token).symbol(), " not found");
                    }
                }
            }
        }

        // YEARN PRICE FEEDS
        SingeTokenPriceFeedData[] memory yearnPriceFeeds = yearnPriceFeedsByNetwork[networkId];
        len = yearnPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = yearnPriceFeeds[i].token;
                address yVault = tokenTestSuite.addressOf(t);

                if (yVault == address(0)) {
                    continue;
                }
                address underlying = IYVault(yVault).token();

                address pf = address(
                    new YearnPriceFeed(
                        addressProvider,
                        yVault,
                        priceFeeds[underlying]
                    )
                );

                setPriceFeed(yVault, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // WSTETH_PRICE_FEED
        unchecked {
            Tokens t = wstethPriceFeedByNetwork[networkId].token;
            if (t != Tokens.NO_TOKEN) {
                address wsteth = tokenTestSuite.addressOf(t);

                if (wsteth != address(0)) {
                    address steth = IwstETH(wsteth).stETH();

                    address pf = address(new WstETHPriceFeed(addressProvider, wsteth, priceFeeds[steth]));

                    setPriceFeed(wsteth, pf);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }

        // // WRAPPED AAVE V2 PRICE FEEDS
        GenericLPPriceFeedData[] memory wrappedAaveV2PriceFeeds = wrappedAaveV2PriceFeedsByNetwork[networkId];
        len = wrappedAaveV2PriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = wrappedAaveV2PriceFeeds[i].lpToken;
                address waToken = tokenTestSuite.addressOf(t);

                if (waToken != address(0)) {
                    address underlying = tokenTestSuite.addressOf(wrappedAaveV2PriceFeeds[i].underlying);

                    address pf = address(
                        new WrappedAaveV2PriceFeed(
                        addressProvider,
                        waToken,
                        priceFeeds[underlying]
                        )
                    );

                    setPriceFeed(waToken, pf);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }
        // COMPOUND V2 PRICE FEEDS
        GenericLPPriceFeedData[] memory compoundV2PriceFeeds = compoundV2PriceFeedsByNetwork[networkId];
        len = compoundV2PriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = compoundV2PriceFeeds[i].lpToken;
                address cToken = tokenTestSuite.addressOf(t);

                if (cToken == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(compoundV2PriceFeeds[i].underlying);

                address pf = address(
                    new WrappedAaveV2PriceFeed(
                        addressProvider,
                        cToken,
                        priceFeeds[underlying]
                    )
                );

                setPriceFeed(cToken, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // ERC4626 PRICE FEEDS
        GenericLPPriceFeedData[] memory erc4626PriceFeeds = erc4626PriceFeedsByNetwork[networkId];
        len = erc4626PriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = erc4626PriceFeeds[i].lpToken;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(erc4626PriceFeeds[i].underlying);

                address pf = address(
                    new WrappedAaveV2PriceFeed(
                        addressProvider,
                        token,
                        priceFeeds[underlying]
                    )
                );

                setPriceFeed(token, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // REDSTONE PRICE FEEDS
        RedStonePriceFeedData[] memory redStonePriceFeeds = redStonePriceFeedsByNetwork[networkId];
        len = redStonePriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                RedStonePriceFeedData memory redStonePriceFeedData = redStonePriceFeeds[i];
                Tokens t = redStonePriceFeedData.token;
                address token = tokenTestSuite.addressOf(t);

                address pf = address(
                    new RedstonePriceFeed(
                       redStonePriceFeedData.tokenSymbol,
                        redStonePriceFeedData.dataFeedId,
                        redStonePriceFeedData.signers,
                         redStonePriceFeedData.signersThreshold
                    )
                );

                setPriceFeed(token, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        priceFeedConfigLength = priceFeedConfig.length;
    }

    function setPriceFeed(address token, address priceFeed) internal {
        priceFeeds[token] = priceFeed;
        priceFeedConfig.push(PriceFeedConfig({token: token, priceFeed: priceFeed}));
    }

    function getPriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfig;
    }
}
