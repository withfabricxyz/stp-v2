// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {InitParams, Tier} from "./Index.sol";
import {CurveParams, RewardParams} from "./Rewards.sol";

/// @dev Deployment parameters for a new subscription contract
struct DeployParams {
    /// @dev the client fee basis points
    uint16 clientFeeBps;
    /// @dev the client referral share basis points
    uint16 clientReferralShareBps;
    /// @dev the client fee recipient
    address clientFeeRecipient;
    /// @dev An identifer to help track deployments via Deploy event. This should only be used in
    ///      conjunction with the expected owner account to prevent impersonation via front or back running.
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

/// @dev A view of the fee schedule for the factory
struct FeeScheduleView {
    /// @dev the fee for deploying a new subscription contract
    uint256 deployFee;
    /// @dev the protocol fee basis points set on deployed contracts
    uint256 protocolFeeBps;
    /// @dev the protocol fee recipient
    address recipient;
}
