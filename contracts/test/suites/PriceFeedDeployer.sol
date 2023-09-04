// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {ISupportedContracts, Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import {
    PriceFeedDataLive,
    ChainlinkPriceFeedData,
    BoundedPriceFeedData,
    SingeTokenPriceFeedData,
    CompositePriceFeedData,
    CurvePriceFeedData,
    CrvUsdPriceFeedData,
    GenericLPPriceFeedData,
    TheSamePriceFeedData,
    BalancerLPPriceFeedData,
    RedStonePriceFeedData
} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedDataLive.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {PriceOracleV3} from "@gearbox-protocol/core-v3/contracts/core/PriceOracleV3.sol";
import {IAddressProviderV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";
import {IACL} from "@gearbox-protocol/core-v2/contracts/interfaces/IACL.sol";

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";

import {YearnPriceFeed} from "../../oracles/yearn/YearnPriceFeed.sol";
import {WstETHPriceFeed} from "../../oracles/lido/WstETHPriceFeed.sol";
import {CurveUSDPriceFeed} from "../../oracles/curve/CurveUSDPriceFeed.sol";
import {CurveStableLPPriceFeed} from "../../oracles/curve/CurveStableLPPriceFeed.sol";
import {CurveCryptoLPPriceFeed} from "../../oracles/curve/CurveCryptoLPPriceFeed.sol";
import {WrappedAaveV2PriceFeed} from "../../oracles/aave/WrappedAaveV2PriceFeed.sol";
import {CompoundV2PriceFeed} from "../../oracles/compound/CompoundV2PriceFeed.sol";
import {ERC4626PriceFeed} from "../../oracles/erc4626/ERC4626PriceFeed.sol";

import {ZeroPriceFeed} from "../../oracles/ZeroPriceFeed.sol";
import {CompositePriceFeed} from "../../oracles/CompositePriceFeed.sol";
import {BoundedPriceFeed} from "../../oracles/BoundedPriceFeed.sol";

import {RedstonePriceFeed} from "../../oracles/updatable/RedstonePriceFeed.sol";

import {BPTStablePriceFeed} from "../../oracles/balancer/BPTStablePriceFeed.sol";
import {BPTWeightedPriceFeed} from "../../oracles/balancer/BPTWeightedPriceFeed.sol";

import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {IstETHPoolGateway} from "../../interfaces/curve/IstETHPoolGateway.sol";

import {PriceFeedParams} from "../../oracles/PriceFeedParams.sol";

contract PriceFeedDeployer is Test, PriceFeedDataLive {
    TokensTestSuite public tokenTestSuite;
    mapping(address => address) public priceFeeds;
    PriceFeedConfig[] public priceFeedConfig;
    mapping(address => uint32) public stalenessPeriods;
    uint256 public priceFeedConfigLength;
    uint256 public immutable chainId;

    constructor(
        uint256 _chainId,
        address addressProvider,
        TokensTestSuite _tokenTestSuite,
        ISupportedContracts supportedContracts
    ) PriceFeedDataLive() {
        chainId = _chainId;
        tokenTestSuite = _tokenTestSuite;
        // CHAINLINK PRICE FEEDS
        ChainlinkPriceFeedData[] memory chainlinkPriceFeeds = chainlinkPriceFeedsByNetwork[chainId];
        uint256 len = chainlinkPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pf = chainlinkPriceFeeds[i].priceFeed;
                Tokens t = chainlinkPriceFeeds[i].token;

                address token = tokenTestSuite.addressOf(t);

                if (token != address(0) && pf != address(0)) {
                    setPriceFeed(token, pf, chainlinkPriceFeeds[i].stalenessPeriod);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }

        // BOUNDED PRICE FEEDS
        {
            BoundedPriceFeedData[] memory boundedPriceFeeds = boundedPriceFeedsByNetwork[chainId];
            len = boundedPriceFeeds.length;
            unchecked {
                for (uint256 i = 0; i < len; ++i) {
                    Tokens t = boundedPriceFeeds[i].token;

                    address token = tokenTestSuite.addressOf(t);

                    if (token != address(0)) {
                        address pf = address(
                            new BoundedPriceFeed(
                                boundedPriceFeeds[i].priceFeed,
                                boundedPriceFeeds[i].stalenessPeriod,
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

        // COMPOSITE PRICE FEEDS
        {
            CompositePriceFeedData[] memory compositePriceFeeds = compositePriceFeedsByNetwork[chainId];
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
                                [
                                    PriceFeedParams({
                                        priceFeed: compositePriceFeeds[i].targetToBaseFeed,
                                        stalenessPeriod: compositePriceFeeds[i].targetStalenessPeriod
                                    }),
                                    PriceFeedParams({
                                        priceFeed: compositePriceFeeds[i].baseToUSDFeed,
                                        stalenessPeriod: compositePriceFeeds[i].baseStalenessPeriod
                                    })
                                ]
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
            SingeTokenPriceFeedData[] memory zeroPriceFeeds = zeroPriceFeedsByNetwork[chainId];
            len = zeroPriceFeeds.length;
            if (len > 0) {
                address zeroPF = address(new ZeroPriceFeed());
                unchecked {
                    for (uint256 i; i < len; ++i) {
                        address token = tokenTestSuite.addressOf(zeroPriceFeeds[i].token);
                        if (token != address(0)) {
                            setPriceFeed(token, zeroPF);
                        }
                    }
                }
                vm.label(zeroPF, "ZERO PRICEFEED");
            }
        }

        // crvUSD PRICE FEEDS
        {
            CrvUsdPriceFeedData[] memory crvUSDPriceFeeds = crvUSDPriceFeedsByNetwork[chainId];
            len = crvUSDPriceFeeds.length;
            unchecked {
                for (uint256 i; i < len; ++i) {
                    Tokens t = crvUSDPriceFeeds[i].token;
                    address token = tokenTestSuite.addressOf(t);
                    if (token == address(0)) continue;

                    address underlying = tokenTestSuite.addressOf(crvUSDPriceFeeds[i].underlying);
                    address pf = address(
                        new CurveUSDPriceFeed(
                            addressProvider,
                            token,
                            supportedContracts.addressOf(crvUSDPriceFeeds[i].pool),
                            priceFeeds[underlying],
                            stalenessPeriods[underlying]
                        )
                    );

                    setPriceFeed(token, pf);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }

        // CURVE STABLE PRICE FEEDS
        {
            CurvePriceFeedData[] memory curvePriceFeeds = curvePriceFeedsByNetwork[chainId];
            len = curvePriceFeeds.length;

            unchecked {
                for (uint256 i; i < len; ++i) {
                    Tokens lpToken = curvePriceFeeds[i].lpToken;

                    uint256 nCoins = curvePriceFeeds[i].assets.length;
                    address pf;

                    address pool = supportedContracts.addressOf(curvePriceFeeds[i].pool);

                    address asset0 = tokenTestSuite.addressOf(curvePriceFeeds[i].assets[0]);
                    address asset1 = tokenTestSuite.addressOf(curvePriceFeeds[i].assets[1]);

                    address asset2 = (nCoins > 2) ? tokenTestSuite.addressOf(curvePriceFeeds[i].assets[2]) : address(0);
                    if (nCoins > 2 && asset2 == address(0)) revert("Asset 2 is not defined");

                    address asset3 = (nCoins > 3) ? tokenTestSuite.addressOf(curvePriceFeeds[i].assets[3]) : address(0);
                    if (nCoins > 3 && asset3 == address(0)) revert("Asset 3 is not defined");

                    if (
                        pool != address(0) && tokenTestSuite.addressOf(lpToken) != address(0) && asset0 != address(0)
                            && asset1 != address(0)
                    ) {
                        if (curvePriceFeeds[i].pool == Contracts.CURVE_STETH_GATEWAY) {
                            pool = IstETHPoolGateway(pool).pool();
                        }

                        pf = address(
                            new CurveStableLPPriceFeed(
                                addressProvider,
                                tokenTestSuite.addressOf(lpToken),
                                pool,
                                [
                                    PriceFeedParams({
                                        priceFeed: priceFeeds[asset0],
                                        stalenessPeriod: stalenessPeriods[asset0]
                                    }),
                                    PriceFeedParams({
                                        priceFeed: priceFeeds[asset1],
                                        stalenessPeriod: stalenessPeriods[asset1]
                                    }),
                                    PriceFeedParams({
                                        priceFeed: (nCoins > 2) ? priceFeeds[asset2] : address(0),
                                        stalenessPeriod: stalenessPeriods[asset2]
                                    }),
                                    PriceFeedParams({
                                        priceFeed: (nCoins > 3) ? priceFeeds[asset3] : address(0),
                                        stalenessPeriod: stalenessPeriods[asset3]
                                    })
                                ]
                            )
                        );

                        setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                        vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken))));
                    }
                }
            }
        }

        // CURVE CRYPTO PRICE FEEDS
        CurvePriceFeedData[] memory curveCryptoPriceFeeds = curveCryptoPriceFeedsByNetwork[chainId];
        len = curveCryptoPriceFeeds.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens lpToken = curveCryptoPriceFeeds[i].lpToken;
                uint256 nCoins = curveCryptoPriceFeeds[i].assets.length;
                address pf;

                address pool = supportedContracts.addressOf(curveCryptoPriceFeeds[i].pool);

                address asset0 = tokenTestSuite.addressOf(curveCryptoPriceFeeds[i].assets[0]);
                address asset1 = tokenTestSuite.addressOf(curveCryptoPriceFeeds[i].assets[1]);

                address asset2 =
                    (nCoins > 2) ? tokenTestSuite.addressOf(curveCryptoPriceFeeds[i].assets[2]) : address(0);
                if (nCoins > 2 && asset2 == address(0)) revert("Asset 2 is not defined");

                if (pool != address(0) && tokenTestSuite.addressOf(lpToken) != address(0)) {
                    pf = address(
                        new CurveCryptoLPPriceFeed(
                            addressProvider,
                            tokenTestSuite.addressOf(lpToken),
                            pool,
                            [
                                PriceFeedParams({
                                    priceFeed: priceFeeds[asset0],
                                    stalenessPeriod: stalenessPeriods[asset0]
                                }),
                                PriceFeedParams({
                                    priceFeed: priceFeeds[asset1],
                                    stalenessPeriod: stalenessPeriods[asset1]
                                }),
                                PriceFeedParams({
                                    priceFeed: (nCoins > 2) ? priceFeeds[asset2] : address(0),
                                    stalenessPeriod: stalenessPeriods[asset2]
                                })
                            ]
                        )
                    );

                    setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                    vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken))));
                }
            }
        }

        // wstETH PRICE FEED
        unchecked {
            Tokens t = wstethPriceFeedByNetwork[chainId].token;
            if (t != Tokens.NO_TOKEN) {
                address wsteth = tokenTestSuite.addressOf(t);

                if (wsteth != address(0)) {
                    address steth = IwstETH(wsteth).stETH();

                    address pf = address(
                        new WstETHPriceFeed(
                            addressProvider,
                            wsteth,
                            priceFeeds[steth],
                            stalenessPeriods[steth]
                        )
                    );

                    setPriceFeed(wsteth, pf);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }

        // BALANCER STABLE PRICEFEEDS
        {
            BalancerLPPriceFeedData[] memory balancerStableLPPriceFeeds = balancerStableLPPriceFeedsByNetwork[chainId];
            len = balancerStableLPPriceFeeds.length;

            unchecked {
                for (uint256 i; i < len; ++i) {
                    Tokens lpToken = balancerStableLPPriceFeeds[i].lpToken;

                    address pf;

                    if (tokenTestSuite.addressOf(lpToken) != address(0)) {
                        PriceFeedParams[5] memory pfParams;

                        uint256 nAssets = balancerStableLPPriceFeeds[i].assets.length;
                        for (uint256 j; j < nAssets; ++j) {
                            address asset = tokenTestSuite.addressOf(balancerStableLPPriceFeeds[i].assets[j]);
                            pfParams[j] = PriceFeedParams({
                                priceFeed: priceFeeds[asset],
                                stalenessPeriod: stalenessPeriods[asset]
                            });
                        }

                        pf = address(
                            new BPTStablePriceFeed(
                            addressProvider,
                            tokenTestSuite.addressOf(lpToken),
                            pfParams
                            )
                        );

                        setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                        vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken))));
                    }
                }
            }
        }

        // BALANCER WEIGHTED PRICEFEEDS
        {
            BalancerLPPriceFeedData[] memory balancerWeightedLPPriceFeeds =
                balancerWeightedLPPriceFeedsByNetwork[chainId];
            len = balancerWeightedLPPriceFeeds.length;

            unchecked {
                for (uint256 i; i < len; ++i) {
                    Tokens lpToken = balancerWeightedLPPriceFeeds[i].lpToken;

                    address pf;

                    if (tokenTestSuite.addressOf(lpToken) != address(0)) {
                        uint256 nAssets = balancerWeightedLPPriceFeeds[i].assets.length;

                        PriceFeedParams[] memory pfParams = new PriceFeedParams[](nAssets);
                        for (uint256 j; j < nAssets; ++j) {
                            address asset = tokenTestSuite.addressOf(balancerWeightedLPPriceFeeds[i].assets[j]);
                            pfParams[j] = PriceFeedParams({
                                priceFeed: priceFeeds[asset],
                                stalenessPeriod: stalenessPeriods[asset]
                            });
                        }

                        // console.log("BV", supportedContracts.addressOf(Contracts.BALANCER_VAULT));

                        pf = address(
                            new BPTWeightedPriceFeed(
                            addressProvider,
                            supportedContracts.addressOf(Contracts.BALANCER_VAULT),
                            tokenTestSuite.addressOf(lpToken),
                            pfParams
                            )
                        );

                        setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                        vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken))));
                    }
                }
            }
        }

        // THE SAME PRICEFEEDS
        TheSamePriceFeedData[] memory theSamePriceFeeds = theSamePriceFeedsByNetwork[chainId];
        len = theSamePriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address token = tokenTestSuite.addressOf(theSamePriceFeeds[i].token);

                if (token != address(0)) {
                    address tokenHasSamePriceFeed = tokenTestSuite.addressOf(theSamePriceFeeds[i].tokenHasSamePriceFeed);
                    address pf = priceFeeds[tokenHasSamePriceFeed];
                    if (pf != address(0)) {
                        setPriceFeed(token, pf, stalenessPeriods[tokenHasSamePriceFeed]);
                    } else {
                        console.log("WARNING: Price feed for ", ERC20(token).symbol(), " not found");
                    }
                }
            }
        }

        // YEARN PRICE FEEDS
        SingeTokenPriceFeedData[] memory yearnPriceFeeds = yearnPriceFeedsByNetwork[chainId];
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
                        priceFeeds[underlying],
                        stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(yVault, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // WRAPPED AAVE V2 PRICE FEEDS
        GenericLPPriceFeedData[] memory wrappedAaveV2PriceFeeds = wrappedAaveV2PriceFeedsByNetwork[chainId];
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
                            priceFeeds[underlying],
                            stalenessPeriods[underlying]
                        )
                    );

                    setPriceFeed(waToken, pf);

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }

        // COMPOUND V2 PRICE FEEDS
        GenericLPPriceFeedData[] memory compoundV2PriceFeeds = compoundV2PriceFeedsByNetwork[chainId];
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
                    new CompoundV2PriceFeed(
                        addressProvider,
                        cToken,
                        priceFeeds[underlying],
                        stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(cToken, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // ERC4626 PRICE FEEDS
        GenericLPPriceFeedData[] memory erc4626PriceFeeds = erc4626PriceFeedsByNetwork[chainId];
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
                    new ERC4626PriceFeed(
                        addressProvider,
                        token,
                        priceFeeds[underlying],
                        stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(token, pf);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // REDSTONE PRICE FEEDS
        RedStonePriceFeedData[] memory redStonePriceFeeds = redStonePriceFeedsByNetwork[chainId];
        len = redStonePriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                RedStonePriceFeedData memory redStonePriceFeedData = redStonePriceFeeds[i];
                Tokens t = redStonePriceFeedData.token;
                address token = tokenTestSuite.addressOf(t);

                address pf = address(
                    new RedstonePriceFeed(
                        token,
                        redStonePriceFeedData.dataFeedId,
                        redStonePriceFeedData.signers,
                        redStonePriceFeedData.signersThreshold
                    )
                );

                setPriceFeed(token, pf, 4 minutes);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        priceFeedConfigLength = priceFeedConfig.length;
    }

    function setPriceFeed(address token, address priceFeed) internal {
        setPriceFeed(token, priceFeed, 0);
    }

    function setPriceFeed(address token, address priceFeed, uint32 stalenessPeriod) internal {
        priceFeeds[token] = priceFeed;
        stalenessPeriods[token] = stalenessPeriod;
        priceFeedConfig.push(PriceFeedConfig({token: token, priceFeed: priceFeed, stalenessPeriod: stalenessPeriod}));
    }

    function getPriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfig;
    }

    function addPriceFeeds(address priceOracle) external {
        uint256 len = priceFeedConfig.length;

        address acl = PriceOracleV3(priceOracle).acl();
        address root = IACL(acl).owner();

        for (uint256 i; i < len; ++i) {
            PriceFeedConfig memory pfc = priceFeedConfig[i];
            address token = pfc.token;
            vm.prank(root);
            PriceOracleV3(priceOracle).setPriceFeed(token, pfc.priceFeed, pfc.stalenessPeriod);
        }
    }
}
