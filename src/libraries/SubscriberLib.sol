// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";

/// @dev Library for managing subscription state
library SubscriberLib {
    using SubscriberLib for Subscription;

    error SubscriptionNotActive();

    error SubscriptionGrantInvalidTime();

    error SubscriptionNotFound(address account);

    /// @dev The amount of purchased time remaining for a given subscription
    function purchasedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        if (sub.purchaseExpires <= block.timestamp) return 0;
        return uint48(sub.purchaseExpires - block.timestamp);
    }

    function extend(Subscription storage sub, uint48 numSeconds) internal {
        if (sub.expiresAt > block.timestamp) sub.expiresAt += numSeconds;
        else sub.expiresAt = uint48(block.timestamp + numSeconds);
    }

    function extendPurchase(Subscription storage sub, uint48 numSeconds) internal {
        sub.extend(numSeconds);
        if (sub.purchaseExpires > block.timestamp) sub.purchaseExpires += numSeconds;
        else sub.purchaseExpires = uint48(block.timestamp + numSeconds);
    }

    function extendGrant(Subscription storage sub, uint48 numSeconds) internal {
        sub.extend(numSeconds);
        if (sub.grantExpires > block.timestamp) sub.grantExpires += numSeconds;
        else sub.grantExpires = uint48(block.timestamp + numSeconds);
    }

    function revokeTime(Subscription storage sub) internal returns (uint48) {
        uint48 remaining = sub.grantedTimeRemaining();
        sub.grantExpires = uint48(block.timestamp);
        sub.expiresAt -= remaining;
        return remaining;
    }

    function refundTime(Subscription storage sub) internal returns (uint48) {
        uint48 refundedTime = sub.purchasedTimeRemaining();
        sub.purchaseExpires = uint48(block.timestamp);
        sub.expiresAt -= refundedTime;
        return refundedTime;
    }

    /// @dev The amount of granted time remaining for a given subscription
    function grantedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        if (sub.grantExpires <= block.timestamp) return 0;
        return uint48(sub.grantExpires - block.timestamp);
    }

    function remainingSeconds(Subscription memory sub) internal view returns (uint48) {
        return sub.expiresAt > block.timestamp ? sub.expiresAt - uint48(block.timestamp) : 0;
    }
}
