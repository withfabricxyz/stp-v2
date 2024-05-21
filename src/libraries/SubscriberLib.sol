// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";

/// @dev Library for managing subscription state
library SubscriberLib {
    using SubscriberLib for Subscription;

    /// @dev Extend the expiration time of a subscription (via purchase)
    function extendPurchase(Subscription storage sub, uint48 numSeconds) internal {
        sub.extend(numSeconds);
        if (sub.purchaseExpires > block.timestamp) sub.purchaseExpires += numSeconds;
        else sub.purchaseExpires = uint48(block.timestamp + numSeconds);
    }

    /// @dev Extend the expiration time of a subscription (via grant)
    function extendGrant(Subscription storage sub, uint48 numSeconds) internal {
        sub.extend(numSeconds);
        if (sub.grantExpires > block.timestamp) sub.grantExpires += numSeconds;
        else sub.grantExpires = uint48(block.timestamp + numSeconds);
    }

    /// @dev Revoke all granted time from a subscription
    function revokeTime(Subscription storage sub) internal returns (uint48) {
        uint48 remaining = sub.grantedTimeRemaining();
        sub.grantExpires = uint48(block.timestamp);
        sub.retract(remaining);
        return remaining;
    }

    /// @dev Refund all purchased time from a subscription
    function refundTime(Subscription storage sub) internal returns (uint48) {
        uint48 refundedTime = sub.purchasedTimeRemaining();
        sub.purchaseExpires = uint48(block.timestamp);
        sub.retract(refundedTime);
        return refundedTime;
    }

    /// @dev Reset the expiration time of a subscription (used for tier switching)
    function resetExpires(Subscription storage sub, uint48 expiresAt) internal {
        sub.expiresAt = expiresAt;
        sub.purchaseExpires = expiresAt;
        sub.grantExpires = uint48(block.timestamp);
    }

    /// @dev The amount of purchased time remaining for a given subscription
    function purchasedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        if (sub.purchaseExpires <= block.timestamp) return 0;
        return uint48(sub.purchaseExpires - block.timestamp);
    }

    /// @dev The amount of granted time remaining for a given subscription
    function grantedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        if (sub.grantExpires <= block.timestamp) return 0;
        return uint48(sub.grantExpires - block.timestamp);
    }

    /// @dev The amount of time remaining for a given subscription
    function remainingSeconds(Subscription memory sub) internal view returns (uint48) {
        return sub.expiresAt > block.timestamp ? sub.expiresAt - uint48(block.timestamp) : 0;
    }

    /// @dev Extend the expiration time of a subscription and emit an update event
    function extend(Subscription storage sub, uint48 numSeconds) internal {
        if (sub.expiresAt > block.timestamp) sub.expiresAt += numSeconds;
        else sub.expiresAt = uint48(block.timestamp + numSeconds);
    }

    /// @dev Retract the expiration time of a subscription and emit an update event
    function retract(Subscription storage sub, uint48 numSeconds) internal {
        sub.expiresAt -= numSeconds;
    }
}
