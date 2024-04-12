// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";

/// @dev The initialization parameters for a subscription token
library SubscriberLib {
    using SubscriberLib for Subscription;

    event GrantRevoke(uint256 indexed tokenId, uint48 time, uint48 expiresAt);

    event SwitchTier(uint256 indexed tokenId, uint16 oldTier, uint16 newTier);

    error SubscriptionNotActive();

    error SubscriptionGrantInvalidTime();

    error SubscriptionNotFound(address account);

    error DeactivationFailure();

    function expiresAt(Subscription memory sub) internal pure returns (uint48) {
        uint48 purchase = sub.purchaseOffset + sub.secondsPurchased;
        uint48 grant = sub.grantOffset + sub.secondsGranted;
        return purchase > grant ? purchase : grant;
    }

    /// @dev The amount of purchased time remaining for a given subscription
    function purchasedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        uint256 _expiresAt = sub.purchaseOffset + sub.secondsPurchased;
        if (_expiresAt <= block.timestamp) return 0;
        return uint48(_expiresAt - block.timestamp);
    }

    /// @dev The amount of granted time remaining for a given subscription
    function grantedTimeRemaining(Subscription memory sub) internal view returns (uint48) {
        uint256 _expiresAt = sub.grantOffset + sub.secondsGranted;
        if (_expiresAt <= block.timestamp) return 0;
        return uint48(_expiresAt - block.timestamp);
    }

    function remainingSeconds(Subscription memory sub) internal view returns (uint256) {
        return purchasedTimeRemaining(sub) + grantedTimeRemaining(sub);
    }

    // TODO: Consider how to do expiresAt properly

    // TODO: Lot's of testing?
    function estimatedRefund(Subscription memory sub) internal view returns (uint256) {
        uint48 secondsLeft = purchasedTimeRemaining(sub);
        if (secondsLeft == 0) return 0;
        uint256 divisor = uint256(sub.secondsPurchased / secondsLeft);
        if (divisor == 0) return 0;
        return sub.totalPurchased / divisor;
    }
}
