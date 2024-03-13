// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier} from "../types/Tier.sol";
import {Tier} from "../types/InitParams.sol";

/// @dev The initialization parameters for a subscription token
library TierLib {
    /////////////////////
    // ERRORS
    /////////////////////
    error InvalidTierId();

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
            revert("Supply cap must be >= current count or 0");
        }
        tier.maxSupply = uint32(newCap);
    }

    /////////////////////
    // VIEW FUNCTIONS
    /////////////////////

    function validate(Tier memory tier) internal pure returns (Tier memory) {
        require(tier.periodDurationSeconds > 0, "Period duration must be > 0");
        require(tier.pricePerPeriod > 0, "Price per period must be > 0");

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
}
