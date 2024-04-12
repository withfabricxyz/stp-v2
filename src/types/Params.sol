// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/*
 * Views are read-only interfaces that can be used to access the state of a contract.
 */

/// @dev The advanced parameters for minting a subscription
struct SubscribeParams {
    /// @dev The tier id of the subscription
    uint16 tierId;
    /// @dev For pay-what-you-want tiers
    uint8 numPeriods;
    /// @dev The address of the recipient (token holder)
    address recipient;
    /// @dev The address of the referrer (reward recipient)
    address referrer;
    /// @dev The referral code
    uint256 referralCode;
    /// @dev The number of tokens being transferred
    uint256 purchaseValue;
}

struct RewardPoolParams {
    /// @dev the grace period of inactivity before a sub is slashable
    uint32 slashGracePeriod;
    /// @dev whether the pool is slashable
    bool slashable;
}
