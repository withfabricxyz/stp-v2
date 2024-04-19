// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

struct Holder {
    /// @dev The number of shares earned
    uint256 numShares;
    /// @dev The number of rewards withdrawn
    uint256 rewardsWithdrawn;
    /// @dev A correction value used to calculate the reward balance for a holder
    int256 pointsCorrection;
}

/// @dev The curve parameters for reward pool share issuance
struct CurveParams {
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
    /// @dev slashGracePeriod
    uint32 slashGracePeriod;
    /// @dev whether the pool is slashable
    bool slashable;
}
