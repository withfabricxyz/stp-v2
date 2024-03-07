// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Subscription} from "../types/Subscription.sol";
import {Tier} from "../types/Tier.sol";

/// @dev The initialization parameters for a subscription token
library SubscriptionLib {
    /// @dev Transfer tokens into the contract, either native or ERC20
    function initialize(Subscription storage self, address from) internal returns (uint256) {}

    function expiresAt(Subscription memory self) internal pure returns (uint256) {
        uint256 purchase = self.purchaseOffset + self.secondsPurchased;
        uint256 grant = self.grantOffset + self.secondsGranted;
        return purchase > grant ? purchase : grant;
    }

    /// @dev Determine if a subscription is active
    function isActive(Subscription memory self) internal view returns (bool) {
        return expiresAt(self) > block.timestamp;
    }

    /// @dev The amount of purchased time remaining for a given subscription
    function purchasedTimeRemaining(Subscription memory self) internal view returns (uint256) {
        uint256 _expiresAt = self.purchaseOffset + self.secondsPurchased;
        if (_expiresAt <= block.timestamp) {
            return 0;
        }
        return _expiresAt - block.timestamp;
    }

    /// @dev The amount of granted time remaining for a given subscription
    function grantedTimeRemaining(Subscription memory self) internal view returns (uint256) {
        uint256 _expiresAt = self.grantOffset + self.secondsGranted;
        if (_expiresAt <= block.timestamp) {
            return 0;
        }
        return _expiresAt - block.timestamp;
    }

    function remainingSeconds(Subscription memory self) internal view returns (uint256) {
        return purchasedTimeRemaining(self) + grantedTimeRemaining(self);
    }

    // function purchase(Subscription storage self, Tier storage tier, uint256 numTokens) internal {}
}
