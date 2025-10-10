// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

interface IPendleYT {
    function doCacheIndexSameBlock() external view returns (bool);
    function pyIndexLastUpdatedBlock() external view returns (uint256);
    function pyIndexStored() external view returns (uint256);
}

interface IPendleSY {
    function exchangeRate() external view returns (uint256);
}
