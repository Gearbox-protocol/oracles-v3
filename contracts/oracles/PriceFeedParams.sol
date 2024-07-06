// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

struct PriceFeedParams {
    address priceFeed;
    uint32 stalenessPeriod;
}
