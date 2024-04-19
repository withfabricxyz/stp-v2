// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {InitParams, Tier} from "./Index.sol";
import {CurveParams, RewardParams} from "./Rewards.sol";

/// @dev Fee configuration for agreements and revshare
struct FactoryFeeConfig {
    /// @dev The address to which fees are paid
    address collector;
    /// @dev The basis points for the fee on subscription revenue
    uint16 basisPoints;
    /// @dev The fee for deploying a contract
    uint80 deployFee;
}

/// @dev Deployment parameters for a new subscription contract
struct DeployParams {
    /// @dev the fee configuration id to use for this deployment
    uint256 feeConfigId;
    /// @dev An identifer to help track deployments via Deploy event
    bytes deployKey;
    /// @dev the init parameters for the collection
    InitParams initParams;
    /// @dev the init parameters for the default tier (tier 1)
    Tier tierParams;
    /// @dev the reward parameters for the collection
    RewardParams rewardParams;
    /// @dev Initial reward curve params (curve 0)
    CurveParams curveParams;
}
