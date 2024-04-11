// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Subscription, Tier} from "../types/Index.sol";
import {GateLib} from "./GateLib.sol";
import {SubscriberLib} from "./SubscriberLib.sol";

/// @dev The initialization parameters for a subscription token
library TierLib {
    using SubscriberLib for Subscription;
    using TierLib for Tier;

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

    function checkJoin(State storage state, address account, uint256 numTokens) internal view {
        if (state.id == 0) revert TierNotFound(state.id);
        if (block.timestamp < state.params.startTimestamp) revert TierNotStarted();
        if (state.params.maxSupply != 0 && state.subCount >= state.params.maxSupply) revert TierHasNoSupply(state.id);
        if (numTokens < state.params.initialMintPrice) revert TierInvalidMintPrice(state.params.initialMintPrice);
        GateLib.checkAccount(state.params.gate, account);
    }

    function join(
        State storage state,
        address account,
        Subscription storage sub,
        uint256 numTokens
    ) internal returns (uint256) {
        // checkJoin(state, account, numTokens);
        if (state.id == 0) revert TierNotFound(state.id);
        if (block.timestamp < state.params.startTimestamp) revert TierNotStarted();
        if (state.params.maxSupply != 0 && state.subCount >= state.params.maxSupply) revert TierHasNoSupply(state.id);
        if (numTokens < state.params.initialMintPrice) revert TierInvalidMintPrice(state.params.initialMintPrice);
        GateLib.checkAccount(state.params.gate, account);

        state.subCount += 1;
        sub.tierId = state.id;
        return numTokens - state.params.initialMintPrice;
    }

    function renew(State storage state, Subscription storage sub, uint256 numTokens) internal {
        Tier memory tier = state.params;

        if (tier.paused) revert TierRenewalsPaused();
        if (numTokens < tier.pricePerPeriod) revert TierInvalidRenewalPrice(tier.pricePerPeriod);

        uint48 numSeconds = tokensToSeconds(tier, numTokens);
        uint48 totalFutureSeconds = sub.purchasedTimeRemaining() + numSeconds;

        if (tier.maxCommitmentSeconds > 0 && totalFutureSeconds > tier.maxCommitmentSeconds) {
            revert MaxCommitmentExceeded();
        }

        if (tier.endTimestamp > 0 && (block.timestamp + totalFutureSeconds) > tier.endTimestamp) {
            revert TierEndExceeded();
        }

        // checkRenewal(state.params, sub, numTokens);
        // if(state.id == 0) revert TierNotFound(state.id);
        // if (block.timestamp < state.params.startTimestamp) revert TierNotStarted();
        // if (state.params.maxSupply != 0 && state.subCount >= state.params.maxSupply) revert
        // TierHasNoSupply(state.id);
        // if (numTokens < state.params.initialMintPrice) revert TierInvalidMintPrice(state.params.initialMintPrice);
        // sub.addTime(tokensToSeconds());
        sub.renew(numTokens, numSeconds);

        // return numTokens - state.params.initialMintPrice;
    }

    function checkRenewal(Tier memory tier, Subscription memory sub, uint256 numTokens) internal view {
        if (tier.paused) revert TierRenewalsPaused();
        if (numTokens < tier.pricePerPeriod) revert TierInvalidRenewalPrice(tier.pricePerPeriod);

        uint256 numSeconds = tokensToSeconds(tier, numTokens);
        uint256 totalFutureSeconds = sub.purchasedTimeRemaining() + numSeconds;

        if (tier.maxCommitmentSeconds > 0 && totalFutureSeconds > tier.maxCommitmentSeconds) {
            revert MaxCommitmentExceeded();
        }

        if (tier.endTimestamp > 0 && (block.timestamp + totalFutureSeconds) > tier.endTimestamp) {
            revert TierEndExceeded();
        }
    }

    function tokensToSeconds(Tier memory tier, uint256 numTokens) internal pure returns (uint48) {
        // TODO: numPeriods + remainder
        return uint48(numTokens / (tier.pricePerPeriod / tier.periodDurationSeconds));
    }

    function mintPrice(Tier memory tier, uint256 numPeriods, bool firstMint) internal pure returns (uint256) {
        return tier.pricePerPeriod * numPeriods + (firstMint ? tier.initialMintPrice : 0);
    }

    function tokensPerSecond(Tier memory tier) internal pure returns (uint256) {
        return tier.pricePerPeriod / tier.periodDurationSeconds;
    }
}
