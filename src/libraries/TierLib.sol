// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier, Subscription} from "../types/Index.sol";
import {GateLib} from "./GateLib.sol";

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

    /// @dev The tier price is invalid
    error TierInvalidMintPrice(uint256 mintPrice);

    error TierRenewalsPaused();

    error TierInvalidRenewalPrice(uint256 renewalPrice);

    /////////////////////
    // EVENTS
    /////////////////////

    /// @dev The tier is paused
    event TierPaused(uint16 tierId);

    /// @dev The tier is unpaused
    event TierUnpaused(uint16 tierId);

    /// @dev The tier price has changed
    event TierPriceChange(uint16 tierId, uint256 oldPricePerPeriod, uint256 pricePerPeriod);

    /// @dev the supply cap has changed
    event TierSupplyCapChange(uint16 tierId, uint32 newCap);

    /////////////////////
    // UPDATE FUNCTIONS
    /////////////////////

    function setPricePerPeriod(Tier storage tier, uint256 price) internal {
        uint256 oldPrice = tier.pricePerPeriod;
        tier.pricePerPeriod = price;
        emit TierPriceChange(tier.id, oldPrice, tier.pricePerPeriod);
    }

    function updateSupplyCap(Tier storage tier, uint32 subCount, uint32 newCap) internal {
        if (newCap != 0 && newCap < subCount) {
            revert TierInvalidSupplyCap();
        }
        tier.maxSupply = newCap;
        emit TierSupplyCapChange(tier.id, newCap);
    }

    function pause(Tier storage tier) internal {
        tier.paused = true;
        emit TierPaused(tier.id);
    }

    function unpause(Tier storage tier) internal {
        tier.paused = false;
        emit TierUnpaused(tier.id);
    }

    /////////////////////
    // VIEW FUNCTIONS
    /////////////////////

    function validate(Tier memory tier) internal view returns (Tier memory) {
        if (tier.periodDurationSeconds == 0) {
            revert TierInvalidDuration();
        }

        tier.gate = GateLib.validate(tier.gate);

        // Gates can refer to other tiers, but not self
        if (tier.gate.contractAddress == address(this) && tier.gate.componentId == tier.id) {
            revert GateLib.GateInvalid();
        }

        return tier;
    }

    // function checkMintPrice(Tier memory tier, uint256 numTokens) internal pure {
    //     uint256 minPrice = mintPrice(tier, 1, true);
    //     if (numTokens < minPrice) {
    //         revert TierInvalidMintPrice(minPrice);
    //     }
    // }

    function checkJoin(Tier memory tier, uint32 subCount, address account, uint256 numTokens) internal view {
        if (!hasSupply(tier, subCount)) {
            revert TierHasNoSupply(tier.id);
        }

        if (numTokens < tier.initialMintPrice) {
            revert TierInvalidMintPrice(tier.initialMintPrice);
        }

        GateLib.checkAccount(tier.gate, account);
    }

    function checkRenewal(Tier memory tier, Subscription memory sub, uint256 numTokens) internal pure {
        if (tier.paused) {
            revert TierRenewalsPaused();
        }

        if (numTokens < tier.pricePerPeriod) {
            revert TierInvalidRenewalPrice(tier.pricePerPeriod);
        }

        //
        uint256 numSeconds = tokensToSeconds(tier, numTokens);
        // check the max precommit periods
        // uint256 numPeriods = numTokens / tier.pricePerPeriod;
    }

    function tokensToSeconds(Tier memory tier, uint256 numTokens) internal pure returns (uint256) {
        // TODO: numPeriods + remainder
        return numTokens / tokensPerSecond(tier);
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
}
