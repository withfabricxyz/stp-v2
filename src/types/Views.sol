// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/*
 * Views are read-only interfaces that can be used to access the state of a contract.
 */

struct SubscriberView {
    /// @dev The tier id of the subscription
    uint16 tierId;
    /// @dev The number of seconds purchased
    uint48 secondsPurchased;
    /// @dev The number of seconds granted by the creator
    uint48 secondsGranted;
    /// @dev The tokenId for the subscription
    uint256 tokenId;
    /// @dev The number of tokens transferred
    uint256 totalPurchased;
    /// @dev The expiration timestamp of the subscription
    uint48 expiresAt;
    /// @dev The time the subscription was created
    uint256 estimatedRefund;
}

struct ContractView {
    /// @dev The number of tiers
    uint16 tierCount;
    /// @dev The number of subscriptions
    uint64 subCount;
    /// @dev The global supply cap
    uint64 supplyCap;
    /// @dev The transfer recipient address (0x0 for none)
    address transferRecipient;
    /// @dev The token address or 0x0 for ETH
    address currency;
    /// @dev The creator balance
    uint256 creatorBalance;
}
/// @dev The reward pool balance
// uint256 rewardPoolBalance;
