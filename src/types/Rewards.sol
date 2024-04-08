// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

struct RewardPoolParams {
    /// @dev the name of the reward pool
    string name;
    /// @dev the symbol of the reward pool
    string symbol;
    /// @dev the address of the currency contract
    address currencyAddress;
    /// @dev the grace period of inactivity before a sub is slashable
    uint32 slashGracePeriod;
    /// @dev Transfer unlock date
    uint48 transferUnlockDate;
    /// @dev whether or not the contract accepts multipliers on trusted mints
    bool acceptMultipliers;
    /// @dev trusted minters only?
    bool trustedMintOnly;
    /// @dev a flag to indicate if rewards are slashable
    bool slashable;
}

/// @dev The initialization/config parameters for rewards
struct RewardCurveParams {
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
}

struct RewardParams {
    /// @dev The address of the pool
    address poolAddress;
    /// @dev The number of tokens in the pool
    uint16 bips;
}
