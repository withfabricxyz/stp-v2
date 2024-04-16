// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {IERC5192} from "src/interfaces/IERC5192.sol";
import {SubscriberLib} from "src/libraries/SubscriberLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {Subscription, Tier} from "src/types/Index.sol";

library SubscriptionLib {
    using SubscriptionLib for State;
    using SubscriberLib for Subscription;
    using TierLib for Tier;
    using TierLib for TierLib.State;

    struct State {
        uint64 supplyCap;
        uint64 subCount;
        uint16 tierCount;
        mapping(uint16 => TierLib.State) tiers;
        mapping(address => Subscription) subscriptions;
    }

    /////////////////////
    // EVENTS
    /////////////////////

    /// @dev Emitted when time is purchased (new nft or renewed)
    event Purchase(
        address indexed account,
        uint64 indexed tokenId,
        uint256 tokensTransferred,
        uint48 timePurchased,
        uint48 expiresAt
    );

    /// @dev Emitted when the creator refunds a subscribers remaining time
    event Refund(uint64 indexed tokenId, uint256 tokensTransferred, uint48 timeReclaimed);

    event Grant(uint64 indexed tokenId, uint48 secondsGranted, uint48 expiresAt);

    event GrantRevoke(uint64 indexed tokenId, uint48 time, uint48 expiresAt);

    event SwitchTier(uint64 indexed tokenId, uint16 oldTier, uint16 newTier);

    event TierCreated(uint16 tierId);

    event TierUpdated(uint16 tierId);

    /////////////////////
    // ERRORS
    /////////////////////

    error SubscriptionGrantInvalidTime();

    error InvalidRefund();

    error DeactivationFailure();

    error GlobalSupplyLimitExceeded();

    function createTier(State storage state, Tier memory tierParams) internal {
        tierParams.validate();
        uint16 id = ++state.tierCount;
        state.tiers[id] = TierLib.State({params: tierParams, subCount: 0, id: id});
        emit TierCreated(id);
    }

    function updateTier(State storage state, uint16 tierId, Tier memory tierParams) internal {
        if (state.tiers[tierId].id == 0) revert TierLib.TierNotFound(tierId);
        if (state.tiers[tierId].subCount > tierParams.maxSupply) revert TierLib.TierInvalidSupplyCap();
        tierParams.validate();

        state.tiers[tierId].params = tierParams;
        emit TierUpdated(tierId);
    }

    function deactivateSubscription(State storage state, address account) internal {
        Subscription storage sub = state.subscriptions[account];
        uint16 tierId = sub.tierId;
        if (tierId == 0 || sub.remainingSeconds() > 0) revert DeactivationFailure();
        state.tiers[tierId].subCount -= 1;
        sub.tierId = 0;
        emit SwitchTier(sub.tokenId, tierId, 0);
    }

    function mint(State storage state, address account) internal returns (uint64 tokenId) {
        if (state.supplyCap != 0 && state.subCount >= state.supplyCap) revert GlobalSupplyLimitExceeded();
        tokenId = ++state.subCount;
        state.subscriptions[account].tokenId = tokenId;
    }

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

        emit Purchase(account, sub.tokenId, numTokens, numSeconds, sub.expiresAt);
    }

    function refund(State storage state, address account, uint256 numTokens) internal {
        Subscription storage sub = state.subscriptions[account];
        if (sub.tokenId == 0) revert InvalidRefund();
        uint48 refundedTime = sub.refundTime();
        emit Refund(sub.tokenId, numTokens, refundedTime);
    }

    function switchTier(State storage state, address account, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];
        uint16 subTierId = sub.tierId;
        if (subTierId == tierId) return;
        if (subTierId != 0) state.tiers[subTierId].subCount -= 1;
        state.tiers[tierId].subCount += 1;
        // TODO: what should we do about time?
        // sub.adjustPurchase(oldtier, newtier)
        sub.tierId = tierId;
        emit SwitchTier(sub.tokenId, subTierId, tierId);

        // Soulbound events
        if (state.tiers[tierId].params.transferrable) emit IERC5192.Locked(sub.tokenId);
        else emit IERC5192.Unlocked(sub.tokenId);
    }

    function grant(State storage state, address account, uint48 numSeconds, uint16 tierId) internal {
        if (numSeconds == 0) revert SubscriptionGrantInvalidTime();
        Subscription storage sub = state.subscriptions[account];
        state.switchTier(account, tierId);
        sub.extendGrant(numSeconds);
        emit Grant(sub.tokenId, numSeconds, sub.expiresAt);
    }

    function revokeTime(State storage state, address account) internal {
        Subscription storage sub = state.subscriptions[account];
        uint48 remaining = sub.revokeTime();
        emit GrantRevoke(sub.tokenId, remaining, sub.expiresAt);
    }
}
