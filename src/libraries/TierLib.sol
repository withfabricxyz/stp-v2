// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";
import {GateLib} from "./GateLib.sol";
import {SubscriberLib} from "./SubscriberLib.sol";

/// @dev The initialization parameters for a subscription token
library TierLib {
    using SubscriberLib for Subscription;
    using TierLib for Tier;
    using TierLib for TierLib.State;

    /// @dev scale factor for precision on tokens per second
    uint256 private constant SCALE_FACTOR = 1e18;

    /// @dev The state of a tier
    struct State {
        uint32 subCount;
        uint16 id;
        Tier params;
    }

    /////////////////////
    // ERRORS
    /////////////////////

    /// @dev The tier id must be > 0 and monotonic
    error TierInvalidId();

    /// @dev The tier duration must be > 0
    error TierInvalidDuration();

    /// @dev The supply cap must be >= current count or 0
    error TierInvalidSupplyCap();

    /// @dev The tier id was not found
    error TierNotFound(uint16 tierId);

    /// @dev The tier has no supply
    error TierHasNoSupply(uint16 tierId);

    /// @dev The tier does not allow transferring tokens
    error TierTransferDisabled();

    /// @dev The tier price is invalid
    error TierInvalidMintPrice(uint256 mintPrice);

    /// @dev The tier renewals are paused
    error TierRenewalsPaused();

    /// @dev The tier renewal price is invalid (too low)
    error TierInvalidRenewalPrice(uint256 renewalPrice);

    /// @dev The max commitment has been exceeded (0 = unlimited)
    error MaxCommitmentExceeded();

    /// @dev The tier has not started yet
    error TierNotStarted();

    /// @dev The subscription length has exceeded the tier end time
    error TierEndExceeded();

    /// @dev The tier timing is invalid
    error TierTimingInvalid();

    /////////////////////
    // Checks
    /////////////////////

    /// @dev Validate a tier
    function validate(Tier memory tier) internal view {
        if (tier.periodDurationSeconds == 0) revert TierInvalidDuration();

        // We don't really care about the start timestamp, but it must be less than the end timestamp
        if (tier.endTimestamp != 0) {
            if (tier.endTimestamp <= block.timestamp || tier.endTimestamp <= tier.startTimestamp) {
                revert TierTimingInvalid();
            }
        }

        GateLib.validate(tier.gate);
    }

    /// @dev Check if an account can join a tier (initial price + token gating)
    function checkJoin(State storage state, address account, uint256 numTokens) internal view {
        if (block.timestamp < state.params.startTimestamp) revert TierNotStarted();
        if (state.params.maxSupply != 0 && state.subCount >= state.params.maxSupply) revert TierHasNoSupply(state.id);
        if (numTokens < state.params.initialMintPrice) revert TierInvalidMintPrice(state.params.initialMintPrice);
        GateLib.checkAccount(state.params.gate, account);
    }

    /// @dev Check the renewal price and commitment time for a subscription
    function checkRenewal(
        State storage state,
        Subscription memory sub,
        uint256 numTokens
    ) internal view returns (uint48 numSeconds) {
        Tier memory tier = state.params;

        if (tier.paused) revert TierRenewalsPaused();
        if (numTokens < tier.pricePerPeriod) revert TierInvalidRenewalPrice(tier.pricePerPeriod);

        numSeconds = state.tokensToSeconds(numTokens);
        uint48 totalFutureSeconds = sub.remainingSeconds() + numSeconds;

        if (tier.maxCommitmentSeconds > 0 && totalFutureSeconds > tier.maxCommitmentSeconds) {
            revert MaxCommitmentExceeded();
        }

        if (tier.endTimestamp > 0 && (block.timestamp + totalFutureSeconds) > tier.endTimestamp) {
            revert TierEndExceeded();
        }
    }

    /// @dev Convert tokens to seconds based on the current rate (for free tier any tokens = period duration)
    function tokensToSeconds(State storage state, uint256 numTokens) internal view returns (uint48) {
        if (state.params.pricePerPeriod == 0) return state.params.periodDurationSeconds;
        // Try to reduce precision issues by scaling up before division
        return uint48((numTokens * SCALE_FACTOR) / state.exaTokensPerSecond());
    }

    /// @dev Determine the number of tokens per second, scaled by the SCALE_FACTOR for low decimal tokens like USDC
    function exaTokensPerSecond(State storage state) internal view returns (uint256) {
        return (state.params.pricePerPeriod * SCALE_FACTOR) / state.params.periodDurationSeconds;
    }

    /// @dev Convert a number of seconds on one tier to a number of seconds on another tier.
    ///      If the toTier is free, the number of seconds = periodDuration
    ///      If the fromTier is free, the number of seconds = 0
    function computeSwitchTimeValue(
        State storage toTier,
        State storage fromTier,
        uint48 numSeconds
    ) internal view returns (uint48) {
        return toTier.tokensToSeconds((fromTier.exaTokensPerSecond() * numSeconds) / SCALE_FACTOR);
    }
}
