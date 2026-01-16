// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {BoundedPriceFeed} from "../../contracts/oracles/BoundedPriceFeed.sol";
import {CompositePriceFeed} from "../../contracts/oracles/CompositePriceFeed.sol";
import {ZeroPriceFeed} from "../../contracts/oracles/ZeroPriceFeed.sol";
// import {BPTStablePriceFeed} from "../../contracts/oracles/balancer/BPTStablePriceFeed.sol";
// import {BPTWeightedPriceFeed} from "../../contracts/oracles/balancer/BPTWeightedPriceFeed.sol";
import {CurveCryptoLPPriceFeed} from "../../contracts/oracles/curve/CurveCryptoLPPriceFeed.sol";
import {CurveStableLPPriceFeed} from "../../contracts/oracles/curve/CurveStableLPPriceFeed.sol";
import {CurveTWAPPriceFeed} from "../../contracts/oracles/curve/CurveTWAPPriceFeed.sol";
// import {CurveUSDPriceFeed} from "../../contracts/oracles/curve/CurveUSDPriceFeed.sol";
import {ERC4626PriceFeed} from "../../contracts/oracles/erc4626/ERC4626PriceFeed.sol";
// import {KodiakIslandPriceFeed} from "../../contracts/oracles/kodiak/KodiakIslandPriceFeed.sol";
import {WstETHPriceFeed} from "../../contracts/oracles/lido/WstETHPriceFeed.sol";
// import {MellowLRTPriceFeed} from "../../contracts/oracles/mellow/MellowLRTPriceFeed.sol";
import {PendleTWAPPTPriceFeed} from "../../contracts/oracles/pendle/PendleTWAPPTPriceFeed.sol";
// import {YearnPriceFeed} from "../../contracts/oracles/yearn/YearnPriceFeed.sol";

contract Upload_2025_10_21_Oracles is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](15);
        bytecodes[0].contractType = "PRICE_FEED::BOUNDED";
        bytecodes[0].version = 3_11;
        bytecodes[0].initCode = type(BoundedPriceFeed).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/BoundedPriceFeed.sol";

        bytecodes[1].contractType = "PRICE_FEED::COMPOSITE";
        bytecodes[1].version = 3_11;
        bytecodes[1].initCode = type(CompositePriceFeed).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/CompositePriceFeed.sol";

        bytecodes[2].contractType = "PRICE_FEED::ZERO";
        bytecodes[2].version = 3_11;
        bytecodes[2].initCode = type(ZeroPriceFeed).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/ZeroPriceFeed.sol";

        bytecodes[3].contractType = "PRICE_FEED::BALANCER_STABLE";
        bytecodes[3].version = 3_11;
        // bytecodes[3].initCode = type(BPTStablePriceFeed).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/balancer/BPTStablePriceFeed.sol";

        bytecodes[4].contractType = "PRICE_FEED::BALANCER_WEIGHTED";
        bytecodes[4].version = 3_11;
        // bytecodes[4].initCode = type(BPTWeightedPriceFeed).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/balancer/BPTWeightedPriceFeed.sol";

        bytecodes[5].contractType = "PRICE_FEED::CURVE_CRYPTO";
        bytecodes[5].version = 3_11;
        bytecodes[5].initCode = type(CurveCryptoLPPriceFeed).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/curve/CurveCryptoLPPriceFeed.sol";

        bytecodes[6].contractType = "PRICE_FEED::CURVE_STABLE";
        bytecodes[6].version = 3_11;
        bytecodes[6].initCode = type(CurveStableLPPriceFeed).creationCode;
        bytecodes[6].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/curve/CurveStableLPPriceFeed.sol";

        bytecodes[7].contractType = "PRICE_FEED::CURVE_TWAP";
        bytecodes[7].version = 3_11;
        bytecodes[7].initCode = type(CurveTWAPPriceFeed).creationCode;
        bytecodes[7].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/curve/CurveTWAPPriceFeed.sol";

        bytecodes[8].contractType = "PRICE_FEED::CURVE_USD";
        bytecodes[8].version = 3_11;
        // bytecodes[8].initCode = type(CurveUSDPriceFeed).creationCode;
        bytecodes[8].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/curve/CurveUSDPriceFeed.sol";

        bytecodes[9].contractType = "PRICE_FEED::ERC4626";
        bytecodes[9].version = 3_11;
        bytecodes[9].initCode = type(ERC4626PriceFeed).creationCode;
        bytecodes[9].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/erc4626/ERC4626PriceFeed.sol";

        bytecodes[10].contractType = "PRICE_FEED::KODIAK_ISLAND";
        bytecodes[10].version = 3_11;
        // bytecodes[10].initCode = type(KodiakIslandPriceFeed).creationCode;
        bytecodes[10].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/kodiak/KodiakIslandPriceFeed.sol";

        bytecodes[11].contractType = "PRICE_FEED::WSTETH";
        bytecodes[11].version = 3_11;
        bytecodes[11].initCode = type(WstETHPriceFeed).creationCode;
        bytecodes[11].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/lido/WstETHPriceFeed.sol";

        bytecodes[12].contractType = "PRICE_FEED::MELLOW_LRT";
        bytecodes[12].version = 3_11;
        // bytecodes[12].initCode = type(MellowLRTPriceFeed).creationCode;
        bytecodes[12].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/mellow/MellowLRTPriceFeed.sol";

        bytecodes[13].contractType = "PRICE_FEED::PENDLE_PT_TWAP";
        bytecodes[13].version = 3_11;
        bytecodes[13].initCode = type(PendleTWAPPTPriceFeed).creationCode;
        bytecodes[13].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/pendle/PendleTWAPPTPriceFeed.sol";

        bytecodes[14].contractType = "PRICE_FEED::YEARN";
        bytecodes[14].version = 3_11;
        // bytecodes[14].initCode = type(YearnPriceFeed).creationCode;
        bytecodes[14].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/64a386a25d24ad5984926a3f624c93c7c32c92c9/contracts/oracles/yearn/YearnPriceFeed.sol";
    }
}
