// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {PythStructs} from "./PythStructs.sol";

interface IPyth {
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
    function latestPriceInfoPublishTime(bytes32 priceFeedId) external view returns (uint64);
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256 feeAmount);
}
