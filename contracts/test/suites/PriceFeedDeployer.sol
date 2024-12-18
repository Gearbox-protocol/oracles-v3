// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
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
    RedStonePriceFeedData,
    PendlePriceFeedData
} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedDataLive.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {PriceOracleV3} from "@gearbox-protocol/core-v3/contracts/core/PriceOracleV3.sol";
import {IAddressProviderV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";
import {IACL} from "@gearbox-protocol/core-v2/contracts/interfaces/IACL.sol";

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";

import {WrappedAaveV2PriceFeed} from "../../oracles/aave/WrappedAaveV2PriceFeed.sol";
import {BPTStablePriceFeed} from "../../oracles/balancer/BPTStablePriceFeed.sol";
import {BPTWeightedPriceFeed} from "../../oracles/balancer/BPTWeightedPriceFeed.sol";
import {CompoundV2PriceFeed} from "../../oracles/compound/CompoundV2PriceFeed.sol";
import {CurveCryptoLPPriceFeed} from "../../oracles/curve/CurveCryptoLPPriceFeed.sol";
import {CurveStableLPPriceFeed} from "../../oracles/curve/CurveStableLPPriceFeed.sol";
import {CurveUSDPriceFeed} from "../../oracles/curve/CurveUSDPriceFeed.sol";
import {ERC4626PriceFeed} from "../../oracles/erc4626/ERC4626PriceFeed.sol";
import {WstETHPriceFeed} from "../../oracles/lido/WstETHPriceFeed.sol";
import {RedstonePriceFeed} from "../../oracles/updatable/RedstonePriceFeed.sol";
import {YearnPriceFeed} from "../../oracles/yearn/YearnPriceFeed.sol";
import {BoundedPriceFeed} from "../../oracles/BoundedPriceFeed.sol";
import {CompositePriceFeed} from "../../oracles/CompositePriceFeed.sol";
import {PriceFeedParams} from "../../oracles/PriceFeedParams.sol";
import {ZeroPriceFeed} from "../../oracles/ZeroPriceFeed.sol";
import {MellowLRTPriceFeed} from "../../oracles/mellow/MellowLRTPriceFeed.sol";
import {PendleTWAPPTPriceFeed} from "../../oracles/pendle/PendleTWAPPTPriceFeed.sol";

import {IWAToken} from "../../interfaces/aave/IWAToken.sol";
import {IBalancerStablePool} from "../../interfaces/balancer/IBalancerStablePool.sol";
import {IBalancerWeightedPool} from "../../interfaces/balancer/IBalancerWeightedPool.sol";
import {ICToken} from "../../interfaces/compound/ICToken.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {IstETHPoolGateway} from "../../interfaces/curve/IstETHPoolGateway.sol";
import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {IMellowVault} from "../../interfaces/mellow/IMellowVault.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

contract PriceFeedDeployer is Test, PriceFeedDataLive {
    TokensTestSuite public tokenTestSuite;
    mapping(address => address) public priceFeeds;
    PriceFeedConfig[] public priceFeedConfig;
    PriceFeedConfig[] public priceFeedConfigReserve;
    mapping(address => uint32) public stalenessPeriods;

    address[] public redStoneOracles;
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
                uint256 t = chainlinkPriceFeeds[i].token;

                address token = tokenTestSuite.addressOf(t);

                if (token != address(0) && pf != address(0)) {
                    setPriceFeed(
                        token,
                        pf,
                        chainlinkPriceFeeds[i].stalenessPeriod,
                        chainlinkPriceFeeds[i].trusted,
                        chainlinkPriceFeeds[i].reserve
                    );

                    string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                    vm.label(pf, description);
                }
            }
        }

        // REDSTONE PRICE FEEDS
        unchecked {
            RedStonePriceFeedData[] memory redStonePriceFeeds = redStonePriceFeedsByNetwork[chainId];
            len = redStonePriceFeeds.length;
            for (uint256 i; i < len; ++i) {
                RedStonePriceFeedData memory redStonePriceFeedData = redStonePriceFeeds[i];
                uint256 t = redStonePriceFeedData.token;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) continue;

                address pf = address(
                    new RedstonePriceFeed(
                        token,
                        redStonePriceFeedData.dataFeedId,
                        redStonePriceFeedData.signers,
                        redStonePriceFeedData.signersThreshold
                    )
                );

                redstoneServiceIdByPriceFeed[pf] = redStonePriceFeedData.dataServiceId;

                redStoneOracles.push(pf);
                setPriceFeed(token, pf, 4 minutes, redStonePriceFeedData.trusted, redStonePriceFeedData.reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // BOUNDED PRICE FEEDS
        {
            BoundedPriceFeedData[] memory boundedPriceFeeds = boundedPriceFeedsByNetwork[chainId];
            len = boundedPriceFeeds.length;
            unchecked {
                for (uint256 i = 0; i < len; ++i) {
                    uint256 t = boundedPriceFeeds[i].token;

                    address token = tokenTestSuite.addressOf(t);

                    if (token != address(0)) {
                        address pf = address(
                            new BoundedPriceFeed(
                                boundedPriceFeeds[i].priceFeed,
                                boundedPriceFeeds[i].stalenessPeriod,
                                int256(boundedPriceFeeds[i].upperBound)
                            )
                        );

                        setPriceFeed(token, pf, boundedPriceFeeds[i].trusted, boundedPriceFeeds[i].reserve);

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
                    uint256 t = compositePriceFeeds[i].token;

                    address token = tokenTestSuite.addressOf(t);

                    if (
                        token != address(0)
                            && (
                                compositePriceFeeds[i].targetToBaseFeed != address(0)
                                    || compositePriceFeeds[i].isTargetRedstone
                            )
                            && (
                                compositePriceFeeds[i].baseToUSDFeed != address(0) || compositePriceFeeds[i].isBaseComposite
                            )
                    ) {
                        address targetToBaseFeed;
                        if (compositePriceFeeds[i].isTargetRedstone) {
                            targetToBaseFeed = address(
                                new RedstonePriceFeed(
                                    token,
                                    compositePriceFeeds[i].redstoneTargetToBaseData.dataFeedId,
                                    compositePriceFeeds[i].redstoneTargetToBaseData.signers,
                                    compositePriceFeeds[i].redstoneTargetToBaseData.signersThreshold
                                )
                            );
                            redstoneServiceIdByPriceFeed[targetToBaseFeed] =
                                compositePriceFeeds[i].redstoneTargetToBaseData.dataServiceId;
                            redStoneOracles.push(targetToBaseFeed);
                        } else {
                            targetToBaseFeed = compositePriceFeeds[i].targetToBaseFeed;
                        }

                        address baseToUSDFeed;
                        if (compositePriceFeeds[i].isBaseComposite) {
                            baseToUSDFeed = address(
                                new CompositePriceFeed(
                                    [
                                        PriceFeedParams({
                                            priceFeed: compositePriceFeeds[i].compositeBaseToUSDData.targetToBaseFeed,
                                            stalenessPeriod: compositePriceFeeds[i].compositeBaseToUSDData.targetStalenessPeriod
                                        }),
                                        PriceFeedParams({
                                            priceFeed: compositePriceFeeds[i].compositeBaseToUSDData.baseToUSDFeed,
                                            stalenessPeriod: compositePriceFeeds[i].compositeBaseToUSDData.baseStalenessPeriod
                                        })
                                    ]
                                )
                            );
                        } else {
                            baseToUSDFeed = compositePriceFeeds[i].baseToUSDFeed;
                        }

                        address pf = address(
                            new CompositePriceFeed(
                                [
                                    PriceFeedParams({
                                        priceFeed: targetToBaseFeed,
                                        stalenessPeriod: compositePriceFeeds[i].targetStalenessPeriod
                                    }),
                                    PriceFeedParams({
                                        priceFeed: baseToUSDFeed,
                                        stalenessPeriod: compositePriceFeeds[i].baseStalenessPeriod
                                    })
                                ]
                            )
                        );

                        setPriceFeed(token, pf, compositePriceFeeds[i].trusted, compositePriceFeeds[i].reserve);

                        string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                        vm.label(pf, description);
                    }
                }
            }
            updateRedstoneOraclePriceFeeds();
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
                            setPriceFeed(token, zeroPF, zeroPriceFeeds[i].trusted, zeroPriceFeeds[i].reserve);
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
                    uint256 t = crvUSDPriceFeeds[i].token;
                    address token = tokenTestSuite.addressOf(t);
                    if (token == address(0)) continue;

                    address pool = supportedContracts.addressOf(crvUSDPriceFeeds[i].pool);
                    address underlying = tokenTestSuite.addressOf(crvUSDPriceFeeds[i].underlying);
                    address pf = address(
                        new CurveUSDPriceFeed(
                            addressProvider,
                            ICurvePool(pool).get_virtual_price() * 99 / 100,
                            token,
                            pool,
                            priceFeeds[underlying],
                            stalenessPeriods[underlying]
                        )
                    );

                    setPriceFeed(token, pf, crvUSDPriceFeeds[i].trusted, crvUSDPriceFeeds[i].reserve);

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
                    uint256 lpToken = curvePriceFeeds[i].lpToken;

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
                                ICurvePool(pool).get_virtual_price() * 99 / 100,
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

                        setPriceFeed(
                            tokenTestSuite.addressOf(lpToken),
                            pf,
                            curvePriceFeeds[i].trusted,
                            curvePriceFeeds[i].reserve
                        );
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
                uint256 lpToken = curveCryptoPriceFeeds[i].lpToken;
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
                            ICurvePool(pool).get_virtual_price() * 99 / 100,
                            tokenTestSuite.addressOf(lpToken),
                            pool,
                            [
                                PriceFeedParams({priceFeed: priceFeeds[asset0], stalenessPeriod: stalenessPeriods[asset0]}),
                                PriceFeedParams({priceFeed: priceFeeds[asset1], stalenessPeriod: stalenessPeriods[asset1]}),
                                PriceFeedParams({
                                    priceFeed: (nCoins > 2) ? priceFeeds[asset2] : address(0),
                                    stalenessPeriod: stalenessPeriods[asset2]
                                })
                            ]
                        )
                    );

                    setPriceFeed(
                        tokenTestSuite.addressOf(lpToken),
                        pf,
                        curveCryptoPriceFeeds[i].trusted,
                        curveCryptoPriceFeeds[i].reserve
                    );
                    vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(lpToken))));
                }
            }
        }

        // wstETH PRICE FEED
        unchecked {
            uint256 t = wstethPriceFeedByNetwork[chainId].token;
            if (t != TOKEN_NO_TOKEN) {
                address wsteth = tokenTestSuite.addressOf(t);

                if (wsteth != address(0)) {
                    address steth = IwstETH(wsteth).stETH();

                    address pf = address(
                        new WstETHPriceFeed(
                            addressProvider,
                            IwstETH(wsteth).stEthPerToken() * 99 / 100,
                            wsteth,
                            priceFeeds[steth],
                            stalenessPeriods[steth]
                        )
                    );

                    setPriceFeed(
                        wsteth, pf, wstethPriceFeedByNetwork[chainId].trusted, wstethPriceFeedByNetwork[chainId].reserve
                    );

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
                    uint256 t = balancerStableLPPriceFeeds[i].lpToken;

                    address pf;
                    address lpToken = tokenTestSuite.addressOf(t);

                    if (lpToken != address(0)) {
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
                                addressProvider, IBalancerStablePool(lpToken).getRate() * 99 / 100, lpToken, pfParams
                            )
                        );

                        setPriceFeed(
                            lpToken, pf, balancerStableLPPriceFeeds[i].trusted, balancerStableLPPriceFeeds[i].reserve
                        );
                        vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t))));
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
                    uint256 t = balancerWeightedLPPriceFeeds[i].lpToken;

                    address pf;
                    address lpToken = tokenTestSuite.addressOf(t);

                    if (lpToken != address(0)) {
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
                                IBalancerWeightedPool(lpToken).getRate() * 99 / 100,
                                supportedContracts.addressOf(Contracts.BALANCER_VAULT),
                                lpToken,
                                pfParams
                            )
                        );

                        setPriceFeed(
                            lpToken,
                            pf,
                            balancerWeightedLPPriceFeeds[i].trusted,
                            balancerWeightedLPPriceFeeds[i].reserve
                        );
                        vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t))));
                    }
                }
            }
        }

        // YEARN PRICE FEEDS
        SingeTokenPriceFeedData[] memory yearnPriceFeeds = yearnPriceFeedsByNetwork[chainId];
        len = yearnPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                uint256 t = yearnPriceFeeds[i].token;
                address yVault = tokenTestSuite.addressOf(t);

                if (yVault == address(0)) {
                    continue;
                }
                address underlying = IYVault(yVault).token();

                address pf = address(
                    new YearnPriceFeed(
                        addressProvider,
                        IYVault(yVault).pricePerShare() * 99 / 100,
                        yVault,
                        priceFeeds[underlying],
                        stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(yVault, pf, yearnPriceFeeds[i].trusted, yearnPriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // WRAPPED AAVE V2 PRICE FEEDS
        GenericLPPriceFeedData[] memory wrappedAaveV2PriceFeeds = wrappedAaveV2PriceFeedsByNetwork[chainId];
        len = wrappedAaveV2PriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                uint256 t = wrappedAaveV2PriceFeeds[i].lpToken;
                address waToken = tokenTestSuite.addressOf(t);

                if (waToken != address(0)) {
                    address underlying = tokenTestSuite.addressOf(wrappedAaveV2PriceFeeds[i].underlying);

                    address pf = address(
                        new WrappedAaveV2PriceFeed(
                            addressProvider,
                            IWAToken(waToken).exchangeRate() * 99 / 100,
                            waToken,
                            priceFeeds[underlying],
                            stalenessPeriods[underlying]
                        )
                    );

                    setPriceFeed(waToken, pf, wrappedAaveV2PriceFeeds[i].trusted, wrappedAaveV2PriceFeeds[i].reserve);

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
                uint256 t = compoundV2PriceFeeds[i].lpToken;
                address cToken = tokenTestSuite.addressOf(t);

                if (cToken == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(compoundV2PriceFeeds[i].underlying);

                address pf = address(
                    new CompoundV2PriceFeed(
                        addressProvider,
                        ICToken(cToken).exchangeRateStored() * 99 / 100,
                        cToken,
                        priceFeeds[underlying],
                        stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(cToken, pf, compoundV2PriceFeeds[i].trusted, compoundV2PriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // ERC4626 PRICE FEEDS
        GenericLPPriceFeedData[] memory erc4626PriceFeeds = erc4626PriceFeedsByNetwork[chainId];
        len = erc4626PriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                uint256 t = erc4626PriceFeeds[i].lpToken;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(erc4626PriceFeeds[i].underlying);

                address pf = address(
                    new ERC4626PriceFeed(
                        addressProvider,
                        ERC4626(token).convertToAssets(10 ** ERC4626(token).decimals()) * 99 / 100,
                        token,
                        priceFeeds[underlying],
                        stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(token, pf, erc4626PriceFeeds[i].trusted, erc4626PriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        address addressProvider_ = addressProvider;

        // MELLOW LRT PRICE FEEDS
        GenericLPPriceFeedData[] memory mellowLRTPriceFeeds = mellowLRTPriceFeedsByNetwork[chainId];
        len = mellowLRTPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                uint256 t = mellowLRTPriceFeeds[i].lpToken;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(mellowLRTPriceFeeds[i].underlying);

                IMellowVault.ProcessWithdrawalsStack memory stack = IMellowVault(token).calculateStack();
                uint256 lowerBound = stack.totalValue * WAD * 99 / (stack.totalSupply * 100);

                address pf = address(
                    new MellowLRTPriceFeed(
                        addressProvider_, lowerBound, token, priceFeeds[underlying], stalenessPeriods[underlying]
                    )
                );

                setPriceFeed(token, pf, mellowLRTPriceFeeds[i].trusted, mellowLRTPriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // PENDLE PT PRICE FEEDS
        PendlePriceFeedData[] memory pendlePTPriceFeeds = pendlePriceFeedsByNetwork[chainId];
        len = pendlePTPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                uint256 t = pendlePTPriceFeeds[i].token;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(pendlePTPriceFeeds[i].underlying);

                address pf = address(
                    new PendleTWAPPTPriceFeed(
                        pendlePTPriceFeeds[i].market,
                        priceFeeds[underlying],
                        stalenessPeriods[underlying],
                        pendlePTPriceFeeds[i].twapWindow,
                        pendlePTPriceFeeds[i].priceToSy
                    )
                );

                setPriceFeed(token, pf, pendlePTPriceFeeds[i].trusted, pendlePTPriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        priceFeedConfigLength = priceFeedConfig.length;
    }

    function setPriceFeed(address token, address priceFeed, bool trusted, bool reserve) internal {
        setPriceFeed(token, priceFeed, 0, trusted, reserve);
    }

    function setPriceFeed(address token, address priceFeed, uint32 stalenessPeriod, bool trusted, bool reserve)
        internal
    {
        priceFeeds[token] = priceFeed;
        stalenessPeriods[token] = stalenessPeriod;
        if (reserve) {
            priceFeedConfigReserve.push(
                PriceFeedConfig({token: token, priceFeed: priceFeed, stalenessPeriod: stalenessPeriod, trusted: false})
            );
        } else {
            priceFeedConfig.push(
                PriceFeedConfig({token: token, priceFeed: priceFeed, stalenessPeriod: stalenessPeriod, trusted: trusted})
            );
        }
        _setTheSameAsPFs(token, priceFeed, stalenessPeriod, reserve);
    }

    function _setTheSameAsPFs(address refToken, address priceFeed, uint32 stalenessPeriod, bool reserve) internal {
        TheSamePriceFeedData[] memory theSamePriceFeeds = theSamePriceFeedsByNetwork[chainId];
        uint256 len = theSamePriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address token = tokenTestSuite.addressOf(theSamePriceFeeds[i].token);
                address tokenHasSamePriceFeed = tokenTestSuite.addressOf(theSamePriceFeeds[i].tokenHasSamePriceFeed);

                if (refToken == tokenHasSamePriceFeed && reserve == theSamePriceFeeds[i].reserve && token != address(0))
                {
                    setPriceFeed(token, priceFeed, stalenessPeriod, false, theSamePriceFeeds[i].reserve);
                }
            }
        }
    }

    function getPriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfig;
    }

    function getReservePriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfigReserve;
    }

    function addPriceFeeds(address priceOracle) external {
        address acl = PriceOracleV3(priceOracle).acl();
        address root = IACL(acl).owner();

        uint256 len = priceFeedConfig.length;

        for (uint256 i; i < len; ++i) {
            PriceFeedConfig memory pfc = priceFeedConfig[i];
            address token = pfc.token;

            vm.prank(root);
            PriceOracleV3(priceOracle).setPriceFeed(token, pfc.priceFeed, pfc.stalenessPeriod, pfc.trusted);
        }

        len = priceFeedConfigReserve.length;

        for (uint256 i; i < len; ++i) {
            PriceFeedConfig memory pfc = priceFeedConfigReserve[i];
            address token = pfc.token;

            vm.prank(root);
            PriceOracleV3(priceOracle).setReservePriceFeed(token, pfc.priceFeed, pfc.stalenessPeriod);
        }
    }

    function updateRedstoneOraclePriceFeeds() public {
        uint256 initialTS = block.timestamp;
        uint256 len = redStoneOracles.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pf = redStoneOracles[i];
                bytes32 dataFeedId = RedstonePriceFeed(pf).dataFeedId();
                uint8 signersThreshold = RedstonePriceFeed(pf).getUniqueSignersThreshold();

                string memory dataServiceId = redstoneServiceIdByPriceFeed[pf];
                bytes memory payload =
                    getRedstonePayload(bytes32ToString((dataFeedId)), dataServiceId, Strings.toString(signersThreshold));

                (uint256 expectedPayloadTimestamp,) = abi.decode(payload, (uint256, bytes));

                if (expectedPayloadTimestamp > block.timestamp) {
                    vm.warp(expectedPayloadTimestamp);
                }

                RedstonePriceFeed(pf).updatePrice(payload);
            }
        }

        vm.warp(initialTS);
    }

    function getRedstonePayload(string memory dataFeedId, string memory dataSericeId, string memory signersThreshold)
        internal
        returns (bytes memory)
    {
        string[] memory args = new string[](6);
        args[0] = "npx";
        args[1] = "ts-node";
        args[2] = "./scripts/redstone.ts";
        args[3] = dataSericeId;
        args[4] = dataFeedId;
        args[5] = signersThreshold;

        return vm.ffi(args);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}
