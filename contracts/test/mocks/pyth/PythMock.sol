// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {PythStructs} from "../../../interfaces/pyth/PythStructs.sol";

contract PythMock {
    bool incorrectPublishTime;
    mapping(bytes32 => PythStructs.Price) public priceData;

    function getUpdateFee(bytes[] memory updateData) external pure returns (uint256) {
        return updateData.length;
    }

    function updatePriceFeeds(bytes[] memory updateData) external payable {
        (int64 price, uint256 publishTimestamp, int32 expo, bytes32 priceFeedId) =
            abi.decode(updateData[0], (int64, uint256, int32, bytes32));

        PythStructs.Price storage pData = priceData[priceFeedId];
        pData.price = price;
        pData.publishTime = incorrectPublishTime ? publishTimestamp + 1 : publishTimestamp;
        pData.expo = expo;
    }

    function setPriceData(bytes32 priceFeedId, int64 price, uint64 conf, int32 expo, uint256 publishTime) external {
        PythStructs.Price storage pData = priceData[priceFeedId];
        pData.price = price;
        pData.conf = conf;
        pData.expo = expo;
        pData.publishTime = publishTime;
    }

    function getPriceUnsafe(bytes32 priceFeedId) external view returns (PythStructs.Price memory) {
        return priceData[priceFeedId];
    }

    function latestPriceInfoPublishTime(bytes32 priceFeedId) external view returns (uint256) {
        return priceData[priceFeedId].publishTime;
    }

    function setIncorrectPublishTime(bool status) external {
        incorrectPublishTime = status;
    }
}
