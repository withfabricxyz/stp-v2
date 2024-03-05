// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Subscription} from "../types/Subscription.sol";
import {Tier} from "../types/Tier.sol";

/// @dev The initialization parameters for a subscription token
library SubscriptionLib {
    /// @dev Transfer tokens into the contract, either native or ERC20
    function initialize(Subscription storage self, address from) internal returns (uint256) {}

    function expiresAt(Subscription storage self) internal view returns (uint256) {
        return self.rewardsWithdrawn;
    }

    function purchase(Subscription storage self, Tier storage tier, uint256 numTokens) internal {}
}
