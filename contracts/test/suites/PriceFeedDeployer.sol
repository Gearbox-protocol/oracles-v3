// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
    RedStonePriceFeedData,
    PythPriceFeedData
} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedDataLive.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {PriceOracleV3} from "@gearbox-protocol/core-v3/contracts/core/PriceOracleV3.sol";
import {IACL} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IACL.sol";

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";

import {BPTStablePriceFeed} from "../../oracles/balancer/BPTStablePriceFeed.sol";
import {BPTWeightedPriceFeed} from "../../oracles/balancer/BPTWeightedPriceFeed.sol";
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
import {PythPriceFeed} from "../../oracles/updatable/PythPriceFeed.sol";
import {MellowLRTPriceFeed} from "../../oracles/mellow/MellowLRTPriceFeed.sol";

import {IBalancerStablePool} from "../../interfaces/balancer/IBalancerStablePool.sol";
import {IBalancerWeightedPool} from "../../interfaces/balancer/IBalancerWeightedPool.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {IstETHPoolGateway} from "../../interfaces/curve/IstETHPoolGateway.sol";
import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {IMellowVault} from "../../interfaces/mellow/IMellowVault.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

contract PriceFeedDeployer is Test, PriceFeedDataLive {
    TokensTestSuite public tokenTestSuite;
    mapping(address => address) public priceFeeds;
    mapping(address => address) public reservePriceFeeds;
    PriceFeedConfig[] public priceFeedConfig;
    PriceFeedConfig[] public priceFeedConfigReserve;
    mapping(address => uint32) public stalenessPeriods;
    mapping(address => uint32) public reserveStalenessPeriods;

    address[] public redStoneOracles;
    address[] public pythOracles;
    uint256 public priceFeedConfigLength;
    uint256 public priceFeedConfigReserveLength;
    uint256 public immutable chainId;

    address acl;
    address priceOracle;

    constructor(
        uint256 _chainId,
        address _acl,
        address _priceOracle,
        TokensTestSuite _tokenTestSuite,
        ISupportedContracts supportedContracts
    ) PriceFeedDataLive() {
        chainId = _chainId;
        tokenTestSuite = _tokenTestSuite;
        acl = _acl;
        priceOracle = _priceOracle;
        // CHAINLINK PRICE FEEDS
        ChainlinkPriceFeedData[] memory chainlinkPriceFeeds = chainlinkPriceFeedsByNetwork[chainId];
        uint256 len = chainlinkPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pf = chainlinkPriceFeeds[i].priceFeed;
                Tokens t = chainlinkPriceFeeds[i].token;

                address token = tokenTestSuite.addressOf(t);

                if (token != address(0) && pf != address(0)) {
                    setPriceFeed(token, pf, chainlinkPriceFeeds[i].stalenessPeriod, chainlinkPriceFeeds[i].reserve);

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

                redstoneServiceIdByPriceFeed[pf] = redStonePriceFeedData.dataServiceId;

                redStoneOracles.push(pf);
                setPriceFeed(token, pf, 4 minutes, redStonePriceFeedData.reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
            updateRedstoneOraclePriceFeeds();
        }

        // PYTH PRICE FEEDS
        unchecked {
            PythPriceFeedData[] memory pythPriceFeeds = pythPriceFeedsByNetwork[chainId];
            len = pythPriceFeeds.length;
            for (uint256 i; i < len; ++i) {
                PythPriceFeedData memory pythPriceFeedData = pythPriceFeeds[i];
                Tokens t = pythPriceFeedData.token;
                address token = tokenTestSuite.addressOf(t);

                address pf = address(
                    new PythPriceFeed(
                        token, pythPriceFeedData.priceFeedId, pythPriceFeedData.pyth, pythPriceFeedData.ticker, 10000000
                    )
                );

                vm.deal(pf, 100000);

                pythOracles.push(pf);
                setPriceFeed(token, pf, 4 minutes, pythPriceFeedData.reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
            updatePythOraclePriceFeeds();
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

                        setPriceFeed(token, pf, boundedPriceFeeds[i].reserve);

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

                        setPriceFeed(token, pf, compositePriceFeeds[i].reserve);

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
                            setPriceFeed(token, zeroPF, zeroPriceFeeds[i].reserve);
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

                    address pool = supportedContracts.addressOf(crvUSDPriceFeeds[i].pool);
                    address underlying = tokenTestSuite.addressOf(crvUSDPriceFeeds[i].underlying);
                    address pf = address(
                        new CurveUSDPriceFeed(
                            acl,
                            priceOracle,
                            ICurvePool(pool).get_virtual_price() * 99 / 100,
                            token,
                            pool,
                            _getDeployedFeed(underlying, crvUSDPriceFeeds[i].reserve),
                            _getDeployedStalenessPeriod(underlying, crvUSDPriceFeeds[i].reserve)
                        )
                    );

                    setPriceFeed(token, pf, crvUSDPriceFeeds[i].reserve);

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

                    PriceFeedParams[4] memory pfParams;

                    address asset0 = tokenTestSuite.addressOf(curvePriceFeeds[i].assets[0]);
                    pfParams[0] = PriceFeedParams({
                        priceFeed: _getDeployedFeed(asset0, curvePriceFeeds[i].reserve),
                        stalenessPeriod: _getDeployedStalenessPeriod(asset0, curvePriceFeeds[i].reserve)
                    });

                    address asset1 = tokenTestSuite.addressOf(curvePriceFeeds[i].assets[1]);
                    pfParams[1] = PriceFeedParams({
                        priceFeed: _getDeployedFeed(asset1, curvePriceFeeds[i].reserve),
                        stalenessPeriod: _getDeployedStalenessPeriod(asset1, curvePriceFeeds[i].reserve)
                    });

                    address asset2 = (nCoins > 2) ? tokenTestSuite.addressOf(curvePriceFeeds[i].assets[2]) : address(0);
                    if (nCoins > 2 && asset2 == address(0)) revert("Asset 2 is not defined");
                    pfParams[2] = PriceFeedParams({
                        priceFeed: (nCoins > 2) ? _getDeployedFeed(asset2, curvePriceFeeds[i].reserve) : address(0),
                        stalenessPeriod: _getDeployedStalenessPeriod(asset2, curvePriceFeeds[i].reserve)
                    });

                    address asset3 = (nCoins > 3) ? tokenTestSuite.addressOf(curvePriceFeeds[i].assets[3]) : address(0);
                    if (nCoins > 3 && asset3 == address(0)) revert("Asset 3 is not defined");
                    pfParams[3] = PriceFeedParams({
                        priceFeed: (nCoins > 3) ? _getDeployedFeed(asset3, curvePriceFeeds[i].reserve) : address(0),
                        stalenessPeriod: _getDeployedStalenessPeriod(asset3, curvePriceFeeds[i].reserve)
                    });

                    if (
                        pool != address(0) && tokenTestSuite.addressOf(lpToken) != address(0) && asset0 != address(0)
                            && asset1 != address(0)
                    ) {
                        if (curvePriceFeeds[i].pool == Contracts.CURVE_STETH_GATEWAY) {
                            pool = IstETHPoolGateway(pool).pool();
                        }

                        pf = address(
                            new CurveStableLPPriceFeed(
                                acl,
                                priceOracle,
                                ICurvePool(pool).get_virtual_price() * 99 / 100,
                                tokenTestSuite.addressOf(lpToken),
                                pool,
                                pfParams
                            )
                        );

                        setPriceFeed(tokenTestSuite.addressOf(lpToken), pf, curvePriceFeeds[i].reserve);
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

                PriceFeedParams[3] memory pfParams;

                address asset0 = tokenTestSuite.addressOf(curveCryptoPriceFeeds[i].assets[0]);
                pfParams[0] = PriceFeedParams({
                    priceFeed: _getDeployedFeed(asset0, curveCryptoPriceFeeds[i].reserve),
                    stalenessPeriod: _getDeployedStalenessPeriod(asset0, curveCryptoPriceFeeds[i].reserve)
                });

                address asset1 = tokenTestSuite.addressOf(curveCryptoPriceFeeds[i].assets[1]);
                pfParams[1] = PriceFeedParams({
                    priceFeed: _getDeployedFeed(asset1, curveCryptoPriceFeeds[i].reserve),
                    stalenessPeriod: _getDeployedStalenessPeriod(asset1, curveCryptoPriceFeeds[i].reserve)
                });

                address asset2 =
                    (nCoins > 2) ? tokenTestSuite.addressOf(curveCryptoPriceFeeds[i].assets[2]) : address(0);
                if (nCoins > 2 && asset2 == address(0)) revert("Asset 2 is not defined");
                pfParams[2] = PriceFeedParams({
                    priceFeed: (nCoins > 2) ? _getDeployedFeed(asset2, curveCryptoPriceFeeds[i].reserve) : address(0),
                    stalenessPeriod: _getDeployedStalenessPeriod(asset2, curveCryptoPriceFeeds[i].reserve)
                });

                if (pool != address(0) && tokenTestSuite.addressOf(lpToken) != address(0)) {
                    pf = address(
                        new CurveCryptoLPPriceFeed(
                            acl,
                            priceOracle,
                            ICurvePool(pool).get_virtual_price() * 99 / 100,
                            tokenTestSuite.addressOf(lpToken),
                            pool,
                            pfParams
                        )
                    );

                    setPriceFeed(tokenTestSuite.addressOf(lpToken), pf, curveCryptoPriceFeeds[i].reserve);
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
                            acl,
                            priceOracle,
                            IwstETH(wsteth).stEthPerToken() * 99 / 100,
                            wsteth,
                            _getDeployedFeed(steth, wstethPriceFeedByNetwork[chainId].reserve),
                            _getDeployedStalenessPeriod(steth, wstethPriceFeedByNetwork[chainId].reserve)
                        )
                    );

                    setPriceFeed(wsteth, pf, wstethPriceFeedByNetwork[chainId].reserve);

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
                    Tokens t = balancerStableLPPriceFeeds[i].lpToken;

                    address pf;
                    address lpToken = tokenTestSuite.addressOf(t);

                    if (lpToken != address(0)) {
                        PriceFeedParams[5] memory pfParams;

                        uint256 nAssets = balancerStableLPPriceFeeds[i].assets.length;
                        for (uint256 j; j < nAssets; ++j) {
                            address asset = tokenTestSuite.addressOf(balancerStableLPPriceFeeds[i].assets[j]);
                            pfParams[j] = PriceFeedParams({
                                priceFeed: _getDeployedFeed(asset, balancerStableLPPriceFeeds[i].reserve),
                                stalenessPeriod: _getDeployedStalenessPeriod(asset, balancerStableLPPriceFeeds[i].reserve)
                            });
                        }

                        pf = address(
                            new BPTStablePriceFeed(
                                acl, priceOracle, IBalancerStablePool(lpToken).getRate() * 99 / 100, lpToken, pfParams
                            )
                        );

                        setPriceFeed(lpToken, pf, balancerStableLPPriceFeeds[i].reserve);
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
                    Tokens t = balancerWeightedLPPriceFeeds[i].lpToken;

                    address pf;
                    address lpToken = tokenTestSuite.addressOf(t);

                    if (lpToken != address(0)) {
                        uint256 nAssets = balancerWeightedLPPriceFeeds[i].assets.length;

                        PriceFeedParams[] memory pfParams = new PriceFeedParams[](nAssets);
                        for (uint256 j; j < nAssets; ++j) {
                            address asset = tokenTestSuite.addressOf(balancerWeightedLPPriceFeeds[i].assets[j]);
                            pfParams[j] = PriceFeedParams({
                                priceFeed: _getDeployedFeed(asset, balancerWeightedLPPriceFeeds[i].reserve),
                                stalenessPeriod: _getDeployedStalenessPeriod(asset, balancerWeightedLPPriceFeeds[i].reserve)
                            });
                        }

                        // console.log("BV", supportedContracts.addressOf(Contracts.BALANCER_VAULT));

                        pf = address(
                            new BPTWeightedPriceFeed(
                                acl,
                                priceOracle,
                                IBalancerWeightedPool(lpToken).getRate() * 99 / 100,
                                supportedContracts.addressOf(Contracts.BALANCER_VAULT),
                                lpToken,
                                pfParams
                            )
                        );

                        setPriceFeed(lpToken, pf, balancerWeightedLPPriceFeeds[i].reserve);
                        vm.label(pf, string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t))));
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
                    address pf = _getDeployedFeed(tokenHasSamePriceFeed, theSamePriceFeeds[i].reserve);
                    if (pf != address(0)) {
                        setPriceFeed(
                            token,
                            pf,
                            _getDeployedStalenessPeriod(tokenHasSamePriceFeed, theSamePriceFeeds[i].reserve),
                            theSamePriceFeeds[i].reserve
                        );
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
                        acl,
                        priceOracle,
                        IYVault(yVault).pricePerShare() * 99 / 100,
                        yVault,
                        _getDeployedFeed(underlying, yearnPriceFeeds[i].reserve),
                        _getDeployedStalenessPeriod(underlying, yearnPriceFeeds[i].reserve)
                    )
                );

                setPriceFeed(yVault, pf, yearnPriceFeeds[i].reserve);

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
                        acl,
                        priceOracle,
                        ERC4626(token).convertToAssets(10 ** ERC4626(token).decimals()) * 99 / 100,
                        token,
                        _getDeployedFeed(underlying, erc4626PriceFeeds[i].reserve),
                        _getDeployedStalenessPeriod(underlying, erc4626PriceFeeds[i].reserve)
                    )
                );

                setPriceFeed(token, pf, erc4626PriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        // MELLOW LRT PRICE FEEDS
        GenericLPPriceFeedData[] memory mellowLRTPriceFeeds = mellowLRTPriceFeedsByNetwork[chainId];
        len = mellowLRTPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = mellowLRTPriceFeeds[i].lpToken;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(mellowLRTPriceFeeds[i].underlying);

                IMellowVault.ProcessWithdrawalsStack memory stack = IMellowVault(token).calculateStack();
                uint256 lowerBound = stack.totalValue * WAD * 99 / (stack.totalSupply * 100);

                address pf = address(
                    new MellowLRTPriceFeed(
                        acl,
                        priceOracle,
                        lowerBound,
                        token,
                        _getDeployedFeed(underlying, mellowLRTPriceFeeds[i].reserve),
                        _getDeployedStalenessPeriod(underlying, mellowLRTPriceFeeds[i].reserve),
                        underlying
                    )
                );

                setPriceFeed(token, pf, mellowLRTPriceFeeds[i].reserve);

                string memory description = string(abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t)));
                vm.label(pf, description);
            }
        }

        priceFeedConfigLength = priceFeedConfig.length;
        priceFeedConfigReserveLength = priceFeedConfigReserve.length;
    }

    function setPriceFeed(address token, address priceFeed, bool reserve) internal {
        setPriceFeed(token, priceFeed, 0, reserve);
    }

    function setPriceFeed(address token, address priceFeed, uint32 stalenessPeriod, bool reserve) internal {
        if (reserve) {
            reservePriceFeeds[token] = priceFeed;
            reserveStalenessPeriods[token] = stalenessPeriod;
        } else {
            priceFeeds[token] = priceFeed;
            stalenessPeriods[token] = stalenessPeriod;
        }

        if (reserve) {
            priceFeedConfigReserve.push(
                PriceFeedConfig({token: token, priceFeed: priceFeed, stalenessPeriod: stalenessPeriod})
            );
        } else {
            priceFeedConfig.push(
                PriceFeedConfig({token: token, priceFeed: priceFeed, stalenessPeriod: stalenessPeriod})
            );
        }
    }

    function _getDeployedFeed(address token, bool reserve) internal view returns (address) {
        return reserve ? reservePriceFeeds[token] : priceFeeds[token];
    }

    function _getDeployedStalenessPeriod(address token, bool reserve) internal view returns (uint32) {
        return reserve ? reserveStalenessPeriods[token] : stalenessPeriods[token];
    }

    function getPriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfig;
    }

    function getReservePriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfigReserve;
    }

    function addPriceFeeds(address _priceOracle) external {
        address _acl = PriceOracleV3(_priceOracle).acl();
        address root = Ownable(_acl).owner();

        uint256 len = priceFeedConfig.length;

        for (uint256 i; i < len; ++i) {
            PriceFeedConfig memory pfc = priceFeedConfig[i];
            address token = pfc.token;

            vm.prank(root);
            PriceOracleV3(_priceOracle).setPriceFeed(token, pfc.priceFeed, pfc.stalenessPeriod);
        }

        len = priceFeedConfigReserve.length;

        for (uint256 i; i < len; ++i) {
            PriceFeedConfig memory pfc = priceFeedConfigReserve[i];
            address token = pfc.token;

            vm.prank(root);
            PriceOracleV3(_priceOracle).setReservePriceFeed(token, pfc.priceFeed, pfc.stalenessPeriod);
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

    function updatePythOraclePriceFeeds() public {
        uint256 initialTS = block.timestamp;
        uint256 len = pythOracles.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address payable pf = payable(pythOracles[i]);
                bytes32 priceFeedId = PythPriceFeed(pf).priceFeedId();

                bytes memory payload = getPythPayload(toHex(priceFeedId));

                (uint256 expectedPayloadTimestamp,) = abi.decode(payload, (uint256, bytes));

                if (expectedPayloadTimestamp > block.timestamp) {
                    vm.warp(expectedPayloadTimestamp);
                }

                PythPriceFeed(pf).updatePrice(payload);
            }
        }

        vm.warp(initialTS);
    }

    function getPythPayload(string memory priceFeedId) internal returns (bytes memory) {
        string[] memory args = new string[](4);
        args[0] = "npx";
        args[1] = "ts-node";
        args[2] = "./scripts/pyth.ts";
        args[3] = priceFeedId;

        return vm.ffi(args);
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

    function toHex16(bytes16 data) internal pure returns (bytes32 result) {
        result = bytes32(data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000
            | (bytes32(data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64;
        result = result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000
            | (result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32;
        result = result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000
            | (result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16;
        result = result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000
            | (result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8;
        result = (result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4
            | (result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8;
        result = bytes32(
            0x3030303030303030303030303030303030303030303030303030303030303030 + uint256(result)
                + (
                    uint256(result) + 0x0606060606060606060606060606060606060606060606060606060606060606 >> 4
                        & 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F
                ) * 7
        );
    }

    function toHex(bytes32 data) public pure returns (string memory) {
        return string(abi.encodePacked("0x", toHex16(bytes16(data)), toHex16(bytes16(data << 128))));
    }
}
