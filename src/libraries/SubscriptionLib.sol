// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";

/// @dev The initialization parameters for a subscription token
library SubscriptionLib {
    error SubscriptionGrantInvalidTime();

    error SubscriptionNotFound(address account);

    /// @dev Transfer tokens into the contract, either native or ERC20
    function initialize(Subscription storage sub, address from) internal returns (uint256) {}

    function expiresAt(Subscription memory sub) internal pure returns (uint256) {
        uint256 purchase = sub.purchaseOffset + sub.secondsPurchased;
        uint256 grant = sub.grantOffset + sub.secondsGranted;
        return purchase > grant ? purchase : grant;
    }

    /// @dev Determine if a subscription is active
    function isActive(Subscription memory sub) internal view returns (bool) {
        return expiresAt(sub) > block.timestamp;
    }

    /// @dev The amount of purchased time remaining for a given subscription
    function purchasedTimeRemaining(Subscription memory sub) internal view returns (uint256) {
        uint256 _expiresAt = sub.purchaseOffset + sub.secondsPurchased;
        if (_expiresAt <= block.timestamp) {
            return 0;
        }
        return _expiresAt - block.timestamp;
    }

    /// @dev The amount of granted time remaining for a given subscription
    function grantedTimeRemaining(Subscription memory sub) internal view returns (uint256) {
        uint256 _expiresAt = sub.grantOffset + sub.secondsGranted;
        if (_expiresAt <= block.timestamp) {
            return 0;
        }
        return _expiresAt - block.timestamp;
    }

    function remainingSeconds(Subscription memory sub) internal view returns (uint256) {
        return purchasedTimeRemaining(sub) + grantedTimeRemaining(sub);
    }

    function grantTime(Subscription storage sub, uint256 secondsToGrant) internal {
        if (secondsToGrant == 0) {
            revert SubscriptionGrantInvalidTime();
        }

        // Adjust offset to account for existing time
        if (block.timestamp > sub.grantOffset + sub.secondsGranted) {
            sub.grantOffset = block.timestamp - sub.secondsGranted;
        }

        sub.secondsGranted += secondsToGrant;
        // TODO: I want this, what is the issue with creating the token before?
        // emit Grant(account, sub.tokenId, numSeconds, sub.expiresAt());
    }

    function revokeTime(Subscription storage sub) internal returns (uint256) {
        uint256 remaining = grantedTimeRemaining(sub);
        sub.secondsGranted = 0;
        return remaining;
    }

    // function purchase(Subscription storage sub, Tier storage tier, uint256 numTokens) internal {}
}
