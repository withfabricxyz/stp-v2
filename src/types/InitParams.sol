// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct TierInitParams {
    uint32 periodDurationSeconds;
    uint32 maxSupply;
    uint32 maxMintablePeriods;
    uint8 rewardMultiplier;
    bool paused;
    bool payWhatYouWant;
    uint256 allowList;
    uint256 initialMintPrice;
    uint256 pricePerPeriod;
}

struct FeeParams {
    address collector;
    uint16 bips;
}

struct RewardParams {
    uint16 rewardBps;
    uint8 numRewardHalvings;
    uint48 rewardPeriodSeconds;
    uint48 startTimestamp;
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
    /// @dev the address of the owner of the collection
    address owner;
    /// @dev the address of the ERC20 token used for purchases, or the 0x0 for native
    address erc20TokenAddr;
}

struct DeployParams {
    /// @dev the fee configuration id to use for this deployment
    uint256 feeConfigId;
    // /// @dev the name of the collection
    // string name;
    // /// @dev the symbol of the collection
    // string symbol;
    // /// @dev the metadata URI for the collection
    // string contractUri;
    // /// @dev the metadata URI for the tokens
    // string tokenUri;
    // /// @dev the address of the owner of the collection
    InitParams initParams;
    TierInitParams tierParams;
    RewardParams rewardParams;
}
