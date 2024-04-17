// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {IERC5192} from "src/interfaces/IERC5192.sol";
import {SubscriberLib} from "src/libraries/SubscriberLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {Subscription, Tier} from "src/types/Index.sol";

/// @dev Library for managing core state (tiers, subscriptions, etc)
library SubscriptionLib {
    using SubscriptionLib for State;
    using SubscriberLib for Subscription;
    using TierLib for Tier;
    using TierLib for TierLib.State;

    struct State {
        /// @dev The maximum number of subscriptions that can be minted (updateable)
        uint64 supplyCap;
        /// @dev The total number of subscriptions that have been minted
        uint64 subCount;
        /// @dev The total number of tiers that have been created
        uint16 tierCount;
        /// @dev The state of each tier
        mapping(uint16 => TierLib.State) tiers;
        /// @dev The state of each subscription
        mapping(address => Subscription) subscriptions;
    }

    /////////////////////
    // EVENTS
    /////////////////////

    /// @dev Emitted when time is purchased (new nft or renewed)
    event Purchase(uint64 indexed tokenId, uint256 tokensTransferred, uint48 timePurchased, uint48 expiresAt);

    /// @dev Emitted when the creator refunds a subscribers remaining time
    event Refund(uint64 indexed tokenId, uint256 tokensTransferred, uint48 timeReclaimed);

    /// @dev Emitted when a subscriber is granted time
    event Grant(uint64 indexed tokenId, uint48 secondsGranted, uint48 expiresAt);

    /// @dev Emitted when a subscriber has granted time revoked
    event GrantRevoke(uint64 indexed tokenId, uint48 time, uint48 expiresAt);

    /// @dev Emitted when a subscriber switches tiers
    event SwitchTier(uint64 indexed tokenId, uint16 oldTier, uint16 newTier);

    /// @dev Emitted when a new tier is created
    event TierCreated(uint16 tierId);

    /// @dev Emitted when a tier is updated
    event TierUpdated(uint16 tierId);

    /////////////////////
    // ERRORS
    /////////////////////

    /// @dev The account does not have a subscription
    error SubscriptionNotFound();

    /// @dev The account cannot be deactivated
    error DeactivationFailure();

    /// @dev The global supply cap has been exceeded
    error GlobalSupplyLimitExceeded();

    /// @dev Create a new tier
    function createTier(State storage state, Tier memory tierParams) internal {
        tierParams.validate();
        uint16 id = ++state.tierCount;
        state.tiers[id] = TierLib.State({params: tierParams, subCount: 0, id: id});
        emit TierCreated(id);
    }

    /// @dev Update all parameters of a tier
    function updateTier(State storage state, uint16 tierId, Tier memory tierParams) internal {
        if (state.tiers[tierId].id == 0) revert TierLib.TierNotFound(tierId);
        if (state.tiers[tierId].subCount > tierParams.maxSupply) revert TierLib.TierInvalidSupplyCap();
        tierParams.validate();

        state.tiers[tierId].params = tierParams;
        emit TierUpdated(tierId);
    }

    /// @dev Deactivate a subscription, removing it from the tier
    function deactivateSubscription(State storage state, address account) internal {
        Subscription storage sub = state.subscriptions[account];
        uint16 tierId = sub.tierId;
        if (tierId == 0 || sub.remainingSeconds() > 0) revert DeactivationFailure();
        state.tiers[tierId].subCount -= 1;
        sub.tierId = 0;
        emitSwitchEvents(sub.tokenId, tierId, 0, false);
    }

    /// @dev Mint a new subscription for an account
    function mint(State storage state, address account) internal returns (uint64 tokenId) {
        if (state.supplyCap != 0 && state.subCount >= state.supplyCap) revert GlobalSupplyLimitExceeded();
        tokenId = ++state.subCount;
        state.subscriptions[account].tokenId = tokenId;
    }

    /// @dev Purchase time for a subscriber, potentially switching tiers
    function purchase(State storage state, address account, uint256 numTokens, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];

        // Determine which tier to use. If input is 0, default to current tier.
        // If default tier is 0, default to tier 1. Fallback to tier 1 (default)
        uint16 subTierId = sub.tierId;
        uint16 resolvedTier = tierId == 0 ? subTierId : tierId;
        if (resolvedTier == 0) resolvedTier = 1;

        TierLib.State storage tierState = state.tiers[resolvedTier];

        // Join the tier, if necessary, and deduct the initial mint price
        uint256 tokensForTime = numTokens;
        if (subTierId != resolvedTier) {
            tierState.checkJoin(account, numTokens);
            state.switchTier(account, resolvedTier);
            tokensForTime -= tierState.params.initialMintPrice;
        }

        // Check the renewal and update the subscription
        uint48 numSeconds = tierState.checkRenewal(sub, tokensForTime);
        sub.extendPurchase(numSeconds);

        emit Purchase(sub.tokenId, numTokens, numSeconds, sub.expiresAt);
    }

    /// @dev Refund the remaining time of a subscriber. The creator sets the amount of tokens to refund, which can be 0
    function refund(State storage state, address account, uint256 numTokens) internal {
        Subscription storage sub = state.subscriptions[account];
        if (sub.tokenId == 0) revert SubscriptionNotFound();
        uint48 refundedTime = sub.refundTime();
        emit Refund(sub.tokenId, numTokens, refundedTime);
    }

    /// @dev Switch the tier of a subscriber
    function switchTier(State storage state, address account, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];
        uint16 subTierId = sub.tierId;
        if (subTierId == tierId) return;
        if (subTierId != 0) state.tiers[subTierId].subCount -= 1;
        if (state.tiers[tierId].id == 0) revert TierLib.TierNotFound(tierId);
        state.tiers[tierId].subCount += 1;
        sub.tierId = tierId;

        // Adjust the purchased time if necessary, and clear the granted time
        uint48 proratedTime = 0;
        if (subTierId != 0) {
            proratedTime =
                state.tiers[tierId].computeSwitchTimeValue(state.tiers[subTierId], sub.purchasedTimeRemaining());
        }
        sub.resetExpires(uint48(block.timestamp + proratedTime));

        emitSwitchEvents(sub.tokenId, subTierId, tierId, state.tiers[tierId].params.transferrable);
    }

    /// @dev Grant time to a subscriber. It can be 0 seconds to switch tiers, etc
    function grant(State storage state, address account, uint48 numSeconds, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];
        state.switchTier(account, tierId);
        sub.extendGrant(numSeconds);
        emit Grant(sub.tokenId, numSeconds, sub.expiresAt);
    }

    /// @dev Revoke ONLY granted time from a subscriber
    function revokeTime(State storage state, address account) internal {
        Subscription storage sub = state.subscriptions[account];
        if (sub.tokenId == 0) revert SubscriptionNotFound();
        uint48 remaining = sub.revokeTime();
        emit GrantRevoke(sub.tokenId, remaining, sub.expiresAt);
    }

    /// @dev Emit the switch tier events
    function emitSwitchEvents(uint256 tokenId, uint16 fromTierId, uint16 toTierId, bool locked) private {
        emit SwitchTier(uint64(tokenId), fromTierId, toTierId);

        // Soulbound events
        if (locked) emit IERC5192.Locked(tokenId);
        else emit IERC5192.Unlocked(tokenId);
    }
}
