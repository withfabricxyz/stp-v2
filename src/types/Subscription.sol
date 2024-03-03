// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @dev The subscription struct which holds the state of a subscription for an account
struct Subscription {
    /// @dev The tokenId for the subscription
    uint256 tokenId;
    /// @dev The number of seconds purchased
    uint256 secondsPurchased;
    /// @dev The number of seconds granted by the creator
    uint256 secondsGranted;
    /// @dev A time offset used to adjust expiration for grants
    uint256 grantOffset;
    /// @dev A time offset used to adjust expiration for purchases
    uint256 purchaseOffset;
    /// @dev The number of reward points earned
    uint256 rewardPoints;
    /// @dev The number of rewards withdrawn
    uint256 rewardsWithdrawn;
}
