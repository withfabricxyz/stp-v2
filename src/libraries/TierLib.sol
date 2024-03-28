// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier, Subscription} from "../types/Index.sol";
import {GateLib} from "./GateLib.sol";
import {SubscriptionLib} from "./SubscriptionLib.sol";

/// @dev The initialization parameters for a subscription token
library TierLib {
    using SubscriptionLib for Subscription;
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

    function validate(Tier memory tier) internal view returns (Tier memory) {
        if (tier.periodDurationSeconds == 0) {
            revert TierInvalidDuration();
        }

        // We don't really care about the start timestamp, but it must be less than the end timestamp
        if (tier.endTimestamp != 0) {
            if (tier.endTimestamp <= block.timestamp || tier.endTimestamp <= tier.startTimestamp) {
                revert TierTimingInvalid();
            }
        }

        tier.gate = GateLib.validate(tier.gate);

        // Gates can refer to other tiers, but not self
        if (tier.gate.contractAddress == address(this) && tier.gate.componentId == tier.id) {
            revert GateLib.GateInvalid();
        }

        return tier;
    }

    function checkSupply(Tier memory tier, uint32 subCount) internal pure {
        if (tier.maxSupply != 0 && subCount >= tier.maxSupply) {
            revert TierHasNoSupply(tier.id);
        }
    }

    function checkJoin(Tier memory tier, uint32 subCount, address account, uint256 numTokens) internal view {
        if (block.timestamp < tier.startTimestamp) {
            revert TierNotStarted();
        }

        checkSupply(tier, subCount);

        if (numTokens < tier.initialMintPrice) {
            revert TierInvalidMintPrice(tier.initialMintPrice);
        }

        GateLib.checkAccount(tier.gate, account);
    }

    function checkRenewal(Tier memory tier, Subscription memory sub, uint256 numTokens) internal view {
        if (tier.paused) {
            revert TierRenewalsPaused();
        }

        if (numTokens < tier.pricePerPeriod) {
            revert TierInvalidRenewalPrice(tier.pricePerPeriod);
        }

        uint256 numSeconds = tokensToSeconds(tier, numTokens);
        uint256 totalFutureSeconds = sub.purchasedTimeRemaining() + numSeconds;

        if (tier.maxCommitmentSeconds > 0 && totalFutureSeconds > tier.maxCommitmentSeconds) {
            revert MaxCommitmentExceeded();
        }

        if (tier.endTimestamp > 0 && (block.timestamp + totalFutureSeconds) > tier.endTimestamp) {
            revert TierEndExceeded();
        }
    }

    function tokensToSeconds(Tier memory tier, uint256 numTokens) internal pure returns (uint256) {
        // TODO: numPeriods + remainder
        return numTokens / tokensPerSecond(tier);
    }

    function mintPrice(Tier memory tier, uint256 numPeriods, bool firstMint) internal pure returns (uint256) {
        return tier.pricePerPeriod * numPeriods + (firstMint ? tier.initialMintPrice : 0);
    }

    function tokensPerSecond(Tier memory tier) internal pure returns (uint256) {
        return tier.pricePerPeriod / tier.periodDurationSeconds;
    }
}
