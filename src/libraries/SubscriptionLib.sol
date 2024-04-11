// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";

/// @dev The initialization parameters for a subscription token
library SubscriptionLib {
    error SubscriptionNotActive();

    error SubscriptionGrantInvalidTime();

    error SubscriptionNotFound(address account);

    error DeactivationFailure();

    function expiresAt(Subscription memory sub) internal pure returns (uint256) {
        uint256 purchase = sub.purchaseOffset + sub.secondsPurchased;
        uint256 grant = sub.grantOffset + sub.secondsGranted;
        return purchase > grant ? purchase : grant;
    }

    /// @dev Check if a subscription is active
    function checkActive(Subscription memory sub) internal view {
        if (expiresAt(sub) <= block.timestamp) revert SubscriptionNotActive();
    }

    /// @dev The amount of purchased time remaining for a given subscription
    function purchasedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        uint256 _expiresAt = sub.purchaseOffset + sub.secondsPurchased;
        if (_expiresAt <= block.timestamp) return 0;
        return uint48(_expiresAt - block.timestamp);
    }

    /// @dev The amount of granted time remaining for a given subscription
    function grantedTimeRemaining(Subscription memory sub) internal view returns (uint256) {
        uint256 _expiresAt = sub.grantOffset + sub.secondsGranted;
        if (_expiresAt <= block.timestamp) return 0;
        return _expiresAt - block.timestamp;
    }

    function remainingSeconds(Subscription memory sub) internal view returns (uint256) {
        return purchasedTimeRemaining(sub) + grantedTimeRemaining(sub);
    }

    function grantTime(Subscription storage sub, uint48 secondsToGrant) internal {
        if (secondsToGrant == 0) revert SubscriptionGrantInvalidTime();

        // Adjust offset to account for existing time
        if (block.timestamp > sub.grantOffset + sub.secondsGranted) {
            sub.grantOffset = uint48(block.timestamp - sub.secondsGranted);
        }

        sub.secondsGranted += secondsToGrant;
    }

    function renew(Subscription storage sub, uint256 numTokens, uint48 numSeconds) internal {
        if (block.timestamp > sub.purchaseOffset + sub.secondsPurchased) {
            sub.purchaseOffset = uint48(block.timestamp - sub.secondsPurchased);
        }

        sub.totalPurchased += numTokens;
        sub.secondsPurchased += numSeconds;
    }

    function revokeTime(Subscription storage sub) internal returns (uint256) {
        uint256 remaining = grantedTimeRemaining(sub);
        sub.secondsGranted = 0;
        return remaining;
    }

    // TODO: Lot's of testing?
    function estimatedRefund(Subscription memory sub) internal view returns (uint256) {
        uint48 secondsLeft = purchasedTimeRemaining(sub);
        if (secondsLeft == 0) return 0;
        uint256 divisor = uint256(sub.secondsPurchased / secondsLeft);
        if (divisor == 0) return 0;
        return sub.totalPurchased / divisor;
    }

    function deactivate(Subscription storage sub) internal {
        if (sub.tierId == 0) return;

        if (remainingSeconds(sub) > 0) revert DeactivationFailure();

        sub.tierId = 0;
        // emit Deactivatation(account, sub.tokenId);
    }

    function refund(
        Subscription storage sub,
        uint256 numTokens
    ) internal returns (uint256 refundedTokens, uint48 refundedTime) {
        refundedTime = purchasedTimeRemaining(sub);
        refundedTokens = numTokens > 0 ? numTokens : estimatedRefund(sub);
        // TODO: Checks?
        // TODO: Test
        sub.totalPurchased -= refundedTokens;
        sub.secondsPurchased -= refundedTime;
    }
}
