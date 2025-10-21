// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IMellowChainlinkOracle} from "../../../interfaces/mellow/IMellowChainlinkOracle.sol";

contract MellowChainlinkOracleMock is IMellowChainlinkOracle {
    mapping(address vault => address) public baseTokens;

    function setBaseToken(address vault, address baseToken) external {
        baseTokens[vault] = baseToken;
    }
}
