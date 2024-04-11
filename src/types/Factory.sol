// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {InitParams, Tier} from "./Index.sol";
import {CurveParams, RewardParams, RewardPoolParams} from "./Rewards.sol";

/// @dev Fee configuration for agreements and revshare
struct FactoryFeeConfig {
    address collector;
    uint16 basisPoints;
    uint80 deployFee;
}

struct DeployParams {
    /// @dev the fee configuration id to use for this deployment
    uint256 feeConfigId;
    /// @dev the init parameters for the collection
    InitParams initParams;
    /// @dev the init parameters for the default tier (tier 1)
    Tier tierParams;
    /// @dev the reward parameters for the collection
    RewardParams rewardParams;
}

struct RewardDeployParams {
    /// @dev the reward pool parameters
    RewardPoolParams params;
    /// @dev the curve parameters for calculating token amounts
    CurveParams curveParams;
}
