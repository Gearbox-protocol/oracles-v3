// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {LibString} from "@solady/utils/LibString.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
    PythPriceFeedData,
    PendlePriceFeedData
} from "@gearbox-protocol/sdk-gov/contracts/PriceFeedDataLive.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {PriceOracleV3} from "@gearbox-protocol/core-v3/contracts/core/PriceOracleV3.sol";
import {IACL} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IACL.sol";

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

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
import {PendleTWAPPTPriceFeed} from "../../oracles/pendle/PendleTWAPPTPriceFeed.sol";

import {IBalancerStablePool} from "../../interfaces/balancer/IBalancerStablePool.sol";
import {IBalancerWeightedPool} from "../../interfaces/balancer/IBalancerWeightedPool.sol";
import {ICurvePool} from "../../interfaces/curve/ICurvePool.sol";
import {IstETHPoolGateway} from "../../interfaces/curve/IstETHPoolGateway.sol";
import {IwstETH} from "../../interfaces/lido/IwstETH.sol";
import {IYVault} from "../../interfaces/yearn/IYVault.sol";
import {IMellowVault} from "../../interfaces/mellow/IMellowVault.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

contract PriceFeedDeployer is Test, PriceFeedDataLive {
    using LibString for uint256;
    using LibString for bytes32;

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

    constructor(uint256 _chainId, address _acl, TokensTestSuite _tokenTestSuite, ISupportedContracts supportedContracts)
        PriceFeedDataLive()
    {
        chainId = _chainId;
        tokenTestSuite = _tokenTestSuite;
        acl = _acl;
        // CHAINLINK PRICE FEEDS
        ChainlinkPriceFeedData[] memory chainlinkPriceFeeds = chainlinkPriceFeedsByNetwork[chainId];
        uint256 len = chainlinkPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pf = chainlinkPriceFeeds[i].priceFeed;
                uint256 t = chainlinkPriceFeeds[i].token;

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
                uint256 t = redStonePriceFeedData.token;
                address token = tokenTestSuite.addressOf(t);

                address pf = address(
                    new RedstonePriceFeed(
                        token,
                        redStonePriceFeedData.dataServiceId,
                        redStonePriceFeedData.dataFeedId,
                        redStonePriceFeedData.signers,
                        redStonePriceFeedData.signersThreshold,
                        // TODO: add ticker for Redstone price feeds in sdk-gov
                        string.concat(tokenTestSuite.symbols(t), " / USD")
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
                uint256 t = pythPriceFeedData.token;
                address token = tokenTestSuite.addressOf(t);

                address pf = address(
                    new PythPriceFeed(
                        token, pythPriceFeedData.priceFeedId, pythPriceFeedData.pyth, 10000000, pythPriceFeedData.ticker
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
                    uint256 t = boundedPriceFeeds[i].token;

                    address token = tokenTestSuite.addressOf(t);

                    if (token != address(0)) {
                        address pf = address(
                            new BoundedPriceFeed(
                                boundedPriceFeeds[i].priceFeed,
                                boundedPriceFeeds[i].stalenessPeriod,
                                int256(boundedPriceFeeds[i].upperBound),
                                // TODO: add ticker for bounded price feeds in sdk-gov
                                string.concat(tokenTestSuite.symbols(t), " / USD")
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
                                    compositePriceFeeds[i].redstoneTargetToBaseData.dataServiceId,
                                    compositePriceFeeds[i].redstoneTargetToBaseData.dataFeedId,
                                    compositePriceFeeds[i].redstoneTargetToBaseData.signers,
                                    compositePriceFeeds[i].redstoneTargetToBaseData.signersThreshold,
                                    // TODO: add ticker for Redstone price feeds in sdk-gov
                                    ""
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
                                    ],
                                    // TODO: add ticker for composite price feeds in sdk-gov
                                    ""
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
                                ],
                                // TODO: add ticker for composite price feeds in sdk-gov
                                string.concat(tokenTestSuite.symbols(t), " / USD")
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
                    uint256 t = crvUSDPriceFeeds[i].token;
                    address token = tokenTestSuite.addressOf(t);
                    if (token == address(0)) continue;

                    address pool = supportedContracts.addressOf(crvUSDPriceFeeds[i].pool);
                    address underlying = tokenTestSuite.addressOf(crvUSDPriceFeeds[i].underlying);
                    address pf = address(
                        new CurveUSDPriceFeed(
                            acl,
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
                    uint256 lpToken = curvePriceFeeds[i].lpToken;

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
                uint256 lpToken = curveCryptoPriceFeeds[i].lpToken;
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
            uint256 t = wstethPriceFeedByNetwork[chainId].token;
            if (t != TOKEN_NO_TOKEN) {
                address wsteth = tokenTestSuite.addressOf(t);

                if (wsteth != address(0)) {
                    address steth = IwstETH(wsteth).stETH();

                    address pf = address(
                        new WstETHPriceFeed(
                            acl,
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
                    uint256 t = balancerStableLPPriceFeeds[i].lpToken;

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
                                acl, IBalancerStablePool(lpToken).getRate() * 99 / 100, lpToken, pfParams
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
                    uint256 t = balancerWeightedLPPriceFeeds[i].lpToken;

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
                        acl,
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
                uint256 t = erc4626PriceFeeds[i].lpToken;
                address token = tokenTestSuite.addressOf(t);

                if (token == address(0)) {
                    continue;
                }

                address underlying = tokenTestSuite.addressOf(erc4626PriceFeeds[i].underlying);

                address pf = address(
                    new ERC4626PriceFeed(
                        acl,
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
                        acl,
                        lowerBound,
                        token,
                        _getDeployedFeed(underlying, mellowLRTPriceFeeds[i].reserve),
                        _getDeployedStalenessPeriod(underlying, mellowLRTPriceFeeds[i].reserve)
                    )
                );

                setPriceFeed(token, pf, mellowLRTPriceFeeds[i].reserve);

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
                        _getDeployedFeed(underlying, pendlePTPriceFeeds[i].reserve),
                        _getDeployedStalenessPeriod(underlying, pendlePTPriceFeeds[i].reserve),
                        pendlePTPriceFeeds[i].twapWindow,
                        pendlePTPriceFeeds[i].priceToSy
                    )
                );

                setPriceFeed(token, pf, pendlePTPriceFeeds[i].reserve);

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
                    setPriceFeed(token, priceFeed, stalenessPeriod, theSamePriceFeeds[i].reserve);
                }
            }
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

    function addPriceFeeds(address priceOracle) external {
        address _acl = PriceOracleV3(priceOracle).acl();
        address root = Ownable(_acl).owner();

        uint256 len = priceFeedConfig.length;

        for (uint256 i; i < len; ++i) {
            PriceFeedConfig memory pfc = priceFeedConfig[i];
            address token = pfc.token;

            vm.prank(root);
            PriceOracleV3(priceOracle).setPriceFeed(token, pfc.priceFeed, pfc.stalenessPeriod);
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
                uint256 signersThreshold = RedstonePriceFeed(pf).getUniqueSignersThreshold();

                string memory dataServiceId = redstoneServiceIdByPriceFeed[pf];
                bytes memory payload =
                    getRedstonePayload(dataFeedId.fromSmallString(), dataServiceId, signersThreshold.toString());

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

                bytes memory payload = getPythPayload(uint256(priceFeedId).toHexString());

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
}
