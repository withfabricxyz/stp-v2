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
    /// @dev the address which receives fees
    address collector;
    /// @dev the fee in basis points
    uint16 bips;
}

struct RewardParams {
    /// @dev the reward amount in basis points
    uint16 bips;
    /// @dev the number of periods for which rewards are paid
    uint8 numPeriods;
    /// @dev the period duration in seconds
    uint48 periodSeconds;
    /// @dev the start timestamp for rewards
    uint48 startTimestamp;
    /// @dev the minimum multiplier for rewards
    uint8 minMultiplier;
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
    /// @dev the address of the owner of the collection (default admin)
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
    TierInitParams tierParams;
    /// @dev the reward parameters for the collection
    RewardParams rewardParams;
}
