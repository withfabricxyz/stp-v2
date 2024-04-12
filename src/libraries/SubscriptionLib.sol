// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Currency, CurrencyLib} from "src/libraries/CurrencyLib.sol";

import {SubscriberLib} from "src/libraries/SubscriberLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {Subscription, Tier} from "src/types/Index.sol";

library SubscriptionLib {
    using SubscriptionLib for State;
    using SubscriberLib for Subscription;
    using CurrencyLib for Currency;
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
        uint256 indexed tokenId,
        uint256 tokensTransferred,
        uint256 timePurchased,
        uint256 expiresAt
    );

    /// @dev Emitted when the creator refunds a subscribers remaining time
    event Refund(address indexed account, uint256 indexed tokenId, uint256 tokensTransferred, uint256 timeReclaimed);

    event Grant(address indexed account, uint256 indexed tokenId, uint256 secondsGranted, uint256 expiresAt);

    event GrantRevoke(uint256 indexed tokenId, uint48 time, uint48 expiresAt);

    event SwitchTier(uint256 indexed tokenId, uint16 oldTier, uint16 newTier);

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
        tierParams.validate();
        if (state.tiers[tierId].id == 0) revert TierLib.TierNotFound(tierId);
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

    function mint(State storage state, address account) internal returns (uint256 tokenId) {
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
            tierState.subCount += 1;
            sub.tierId = resolvedTier;
            tokensForTime -= tierState.params.initialMintPrice;
        }

        // Check the renewal and update the subscription
        uint48 numSeconds = tierState.checkRenewal(sub, tokensForTime);
        if (block.timestamp > sub.purchaseOffset + sub.secondsPurchased) {
            sub.purchaseOffset = uint48(block.timestamp - sub.secondsPurchased);
        }
        sub.totalPurchased += numTokens;
        sub.secondsPurchased += numSeconds;

        emit Purchase(account, sub.tokenId, numTokens, numSeconds, sub.expiresAt());
    }

    function refund(State storage state, address account, uint256 numTokens) internal {
        Subscription storage sub = state.subscriptions[account];
        uint48 refundedTime = sub.purchasedTimeRemaining();
        if (numTokens == 0 || numTokens > sub.totalPurchased) revert InvalidRefund();
        sub.totalPurchased -= numTokens;
        sub.secondsPurchased -= refundedTime;
        emit Refund(account, sub.tokenId, numTokens, refundedTime);
    }

    function grant(
        State storage state,
        address account,
        uint48 numSeconds,
        uint16 tierId
    ) internal returns (uint256 tokenId) {
        if (numSeconds == 0) revert SubscriptionGrantInvalidTime();

        Subscription storage sub = state.subscriptions[account];
        tokenId = sub.tokenId;
        if (tokenId == 0) {
            tokenId = state.mint(account);
            sub.tokenId = tokenId;
        }

        sub.tierId = tierId;
        if (block.timestamp > sub.grantOffset + sub.secondsGranted) {
            sub.grantOffset = uint48(block.timestamp - sub.secondsGranted);
        }
        sub.secondsGranted += numSeconds;
        // sub.grantTime(numSeconds);

        emit Grant(account, tokenId, numSeconds, sub.expiresAt());
    }

    function revokeTime(State storage state, address account) internal {
        Subscription storage sub = state.subscriptions[account];
        uint48 remaining = sub.grantedTimeRemaining();
        sub.secondsGranted = 0;
        emit GrantRevoke(sub.tokenId, remaining, uint48(sub.expiresAt()));
    }
}
