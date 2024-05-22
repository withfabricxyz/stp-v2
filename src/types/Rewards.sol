// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

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

/// @dev The slashing parameters for the reward pool. Slashing is a mechanism to to burn shares for a
///      holder who's subscription has lapsed by the amount of time specified in the grace period.
struct RewardParams {
    /// @dev The amount of seconds after which reward shares become slashable (0 = immediately after lapse)
    uint32 slashGracePeriod;
    /// @dev A flag indicating whether the rewards are slashable after expiration + grace period
    bool slashable;
}
