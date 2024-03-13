// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier} from "./Tier.sol";

struct FeeParams {
    /// @dev the address which receives fees
    address collector;
    /// @dev the fee in basis points
    uint16 bips;
}

/// @dev The initialization/config parameters for rewards
struct RewardParams {
    /// @dev the reward amount in basis points
    uint16 bips;
    /// @dev the number of periods for which rewards are paid (acts as the exponent)
    uint8 numPeriods;
    /// @dev The base of the exponential formula for reward calculations
    uint8 formulaBase;
    /// @dev the period duration in seconds
    uint48 periodSeconds;
    /// @dev the start timestamp for rewards
    uint48 startTimestamp;
    /// @dev the minimum multiplier for rewards
    uint8 minMultiplier;
    /// @dev a flag to indicate if rewards are slashable
    bool slashable;
    /// @dev the grace period of inactivity before a sub is slashable
    uint32 slashGracePeriod;
}

/// @dev The initialization parameters for a subscription token
struct InitParams {
    /// @dev the name of the collection
    string name;
    /// @dev the symbol of the collection
    string symbol;
    /// @dev the metadata URI for the collection
    string contractUri;
    /// @dev the metadata URI for the tokens
    string tokenUri;
    /// @dev the address of the owner of the contract (default admin)
    address owner;
    /// @dev the address of the ERC20 token used for purchases, or the 0x0 for native
    address erc20TokenAddr;
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
