// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.25;

import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {IERC4906} from "src/interfaces/IERC4906.sol";
import {SubscriberLib} from "src/libraries/SubscriberLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {Subscription, Tier} from "src/types/Index.sol";

/// @dev Library for managing core state (tiers, subscriptions, etc)
library SubscriptionLib {
    using SubscriptionLib for State;
    using SubscriberLib for Subscription;
    using TierLib for Tier;
    using TierLib for TierLib.State;
    using SafeCastLib for uint256;

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
        emit SwitchTier(sub.tokenId, tierId, 0);
        _updateMetadata(sub.tokenId);
    }

    /// @dev Mint a new subscription for an account
    function mint(State storage state, address account) internal returns (uint64 tokenId) {
        if (state.subCount >= state.supplyCap) revert GlobalSupplyLimitExceeded();
        tokenId = ++state.subCount;
        state.subscriptions[account].tokenId = tokenId;
    }

    /// @dev Purchase time for a subscriber, potentially switching tiers
    function purchase(State storage state, address account, uint256 numTokens, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];

        // Determine which tier to use. If tierId input is 0, the following logic will determine the tier
        // 1. If the subscription exists, it will use the current tier of the subscription
        // 2. If the subscription does not exist, it will default to tier 1
        uint16 subTierId = sub.tierId;
        uint16 resolvedTier = tierId == 0 ? subTierId : tierId;
        if (resolvedTier == 0) resolvedTier = 1;

        TierLib.State storage tierState = state.tiers[resolvedTier];

        // Join the tier, if necessary, and deduct the initial mint price
        uint256 tokensForTime = numTokens;
        if (subTierId != resolvedTier) {
            if (tierState.id == 0) revert TierLib.TierNotFound(resolvedTier);
            tierState.checkJoin(account, numTokens);
            state.switchTier(account, resolvedTier);
            tokensForTime -= tierState.params.initialMintPrice;
        }

        // Check the renewal and update the subscription
        uint48 numSeconds = tierState.checkRenewal(sub, tokensForTime);
        sub.extendPurchase(numSeconds);

        emit Purchase(sub.tokenId, numTokens, numSeconds, sub.expiresAt);
        _updateMetadata(sub.tokenId);
    }

    /// @dev Refund the remaining time of a subscriber. The creator sets the amount of tokens to refund, which can be 0
    function refund(State storage state, address account, uint256 numTokens) internal {
        Subscription storage sub = state.subscriptions[account];
        if (sub.tokenId == 0) revert SubscriptionNotFound();
        uint48 refundedTime = sub.refundTime();
        emit Refund(sub.tokenId, numTokens, refundedTime);
        _updateMetadata(sub.tokenId);
    }

    /// @dev Switch the tier of a subscriber
    function switchTier(State storage state, address account, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];
        uint16 subTierId = sub.tierId;
        if (subTierId == tierId) return;
        if (state.tiers[tierId].id == 0) revert TierLib.TierNotFound(tierId);
        if (subTierId != 0) state.tiers[subTierId].subCount -= 1;

        state.tiers[tierId].subCount += 1;
        sub.tierId = tierId;

        // Adjust the purchased time if necessary, and clear the granted time
        uint48 proratedTime = 0;
        if (subTierId != 0) {
            proratedTime =
                state.tiers[tierId].computeSwitchTimeValue(state.tiers[subTierId], sub.purchasedTimeRemaining());
        }
        sub.resetExpires((block.timestamp + proratedTime).toUint48());

        emit SwitchTier(sub.tokenId, subTierId, tierId);
    }

    /// @dev Grant time to a subscriber. It can be 0 seconds to switch tiers, etc
    function grant(State storage state, address account, uint48 numSeconds, uint16 tierId) internal {
        Subscription storage sub = state.subscriptions[account];
        uint16 resolvedTier = tierId == 0 ? sub.tierId : tierId;
        if (resolvedTier == 0) resolvedTier = 1;
        state.switchTier(account, resolvedTier);
        sub.extendGrant(numSeconds);
        emit Grant(sub.tokenId, numSeconds, sub.expiresAt);
        _updateMetadata(sub.tokenId);
    }

    /// @dev Revoke ONLY granted time from a subscriber
    function revokeTime(State storage state, address account) internal {
        Subscription storage sub = state.subscriptions[account];
        if (sub.tokenId == 0) revert SubscriptionNotFound();
        uint48 remaining = sub.revokeTime();
        emit GrantRevoke(sub.tokenId, remaining, sub.expiresAt);
        _updateMetadata(sub.tokenId);
    }

    /// @dev Emit a metadata update event when a subscription is modified in some way. This occurs when time is
    /// purchased, granted, refunded, or revoked. This will result in unrecommended (per spec) events such as new mints
    function _updateMetadata(uint64 tokenId) private {
        emit IERC4906.MetadataUpdate(tokenId);
    }
}
