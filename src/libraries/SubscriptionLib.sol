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

    event Grant(address indexed account, uint256 indexed tokenId, uint256 secondsGranted, uint256 expiresAt);

    /////////////////////
    // ERRORS
    /////////////////////

    error GlobalSupplyLimitExceeded();

    function createTier(State storage state, Tier memory tierParams) internal {
        tierParams.validate();
        uint16 id = ++state.tierCount;
        state.tiers[id] = TierLib.State({params: tierParams, subCount: 0, id: id});
    }

    function updateTier(State storage state, uint16 tierId, Tier memory tierParams) internal {
        tierParams.validate();
        if (state.tiers[tierId].id == 0) revert TierLib.TierNotFound(tierId);
        state.tiers[tierId].params = tierParams;
    }

    function deactivateSubscription(State storage state, address account) internal {
        uint16 id = state.subscriptions[account].tierId;
        if (id == 0) revert("no");
        state.tiers[id].subCount -= 1;
        state.subscriptions[account].deactivate();
        // emit Deactivatation(account, sub.tokenId);
    }

    function mint(State storage state, address account) internal returns (uint256 tokenId) {
        if (state.supplyCap != 0 && state.subCount >= state.supplyCap) revert GlobalSupplyLimitExceeded();
        tokenId = ++state.subCount;
        state.subscriptions[account].tokenId = tokenId;
    }

    function purchase(
        State storage state,
        address account,
        uint256 numTokens,
        uint16 tierId
    ) internal returns (uint256 tokenId) {
        // Mint a new token if necessary
        tokenId = state.subscriptions[account].tokenId;
        if (tokenId == 0) tokenId = state.mint(account);

        // Determine which tier to use
        uint16 subTierId = state.subscriptions[account].tierId;
        uint16 resolvedTier = tierId == 0 ? subTierId : tierId;
        if (resolvedTier == 0) resolvedTier = 1;

        // Join the tier, if necessary, and deduct the initial mint price
        uint256 tokensForTime = numTokens;
        if (subTierId != resolvedTier) {
            tokensForTime = state.tiers[resolvedTier].join(account, state.subscriptions[account], numTokens);
            // state.subscriptions[account].tierId = resolvedTier;
        }

        state.tiers[resolvedTier].renew(state.subscriptions[account], tokensForTime);

        // emit Purchase(account, tokenId, numTokens, numSeconds, 0, sub.expiresAt());
    }

    function grant(
        State storage state,
        address account,
        uint48 numSeconds,
        uint16 tierId
    ) internal returns (uint256 tokenId) {
        Subscription storage sub = state.subscriptions[account];
        tokenId = sub.tokenId;
        if (tokenId == 0) {
            tokenId = state.mint(account);
            sub.tokenId = tokenId;
        }

        sub.tierId = tierId;
        sub.grantTime(numSeconds);

        emit Grant(account, tokenId, numSeconds, sub.expiresAt());
    }
}
