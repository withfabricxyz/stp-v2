// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @dev Fee configuration for agreements and revshare
struct FactoryFeeConfig {
    address collector;
    uint16 basisPoints;
    uint80 deployFee;
}
