// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier} from "../types/Tier.sol";
import {Tier} from "../types/InitParams.sol";
import {Subscription} from "../types/Subscription.sol";

/// @dev The initialization parameters for a subscription token
library TierLib {
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

    /////////////////////
    // EVENTS
    /////////////////////

    /////////////////////
    // UPDATE FUNCTIONS
    /////////////////////

    function setPricePerPeriod(Tier storage tier, uint32 _periodDurationSeconds) internal {
        tier.periodDurationSeconds = _periodDurationSeconds;
    }

    function updateSupplyCap(Tier storage tier, uint32 subCount, uint32 newCap) internal {
        if (newCap != 0 && newCap < subCount) {
            revert TierInvalidSupplyCap();
        }
        tier.maxSupply = newCap;
    }

    /////////////////////
    // VIEW FUNCTIONS
    /////////////////////

    function validate(Tier memory tier) internal pure returns (Tier memory) {
        if (tier.periodDurationSeconds == 0) {
            revert TierInvalidDuration();
        }
        return tier;
    }

    function mintPrice(Tier memory tier, uint256 numPeriods, bool firstMint) internal pure returns (uint256) {
        return tier.pricePerPeriod * numPeriods + (firstMint ? tier.initialMintPrice : 0);
    }

    function hasSupply(Tier memory tier, uint32 subCount) internal pure returns (bool) {
        return tier.maxSupply == 0 || subCount < tier.maxSupply;
    }

    function tokensPerSecond(Tier memory tier) internal pure returns (uint256) {
        return tier.pricePerPeriod / tier.periodDurationSeconds;
    }

    // function checkPurchase(Tier memory tier, Subscription memory sub, uint256 tokenAmount) internal pure returns (uint256) {
    //     // TODO: Check amount
    //     // TODO: Check period is valid
    //     // TODO: Check max periods
    //     // TODO: Check token gate
    //     return tier.pricePerPeriod / tier.periodDurationSeconds;
    // }
}
