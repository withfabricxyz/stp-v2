// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier} from "../types/Tier.sol";
import {TierInitParams} from "../types/InitParams.sol";

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

    function setPricePerPeriod(Tier storage self, uint32 _periodDurationSeconds) internal {
        self.periodDurationSeconds = _periodDurationSeconds;
    }

    function updateSupplyCap(Tier storage self, uint256 newCap) internal {
        if (newCap != 0 && newCap < self.numSubs) {
            revert("Supply cap must be >= current count or 0");
        }
        self.maxSupply = uint32(newCap);
    }

    /////////////////////
    // VIEW FUNCTIONS
    /////////////////////

    function validateAndBuild(uint8 id, TierInitParams memory self) internal pure returns (Tier memory) {
        require(self.periodDurationSeconds > 0, "Period duration must be > 0");
        require(self.pricePerPeriod > 0, "Price per period must be > 0");

        return Tier({
            id: id,
            periodDurationSeconds: self.periodDurationSeconds,
            paused: self.paused,
            payWhatYouWant: self.payWhatYouWant,
            maxSupply: self.maxSupply,
            numSubs: 0,
            numFrozenSubs: 0,
            rewardMultiplier: self.rewardMultiplier,
            allowList: self.allowList,
            initialMintPrice: self.initialMintPrice,
            pricePerPeriod: self.pricePerPeriod,
            maxMintablePeriods: self.maxMintablePeriods
        });
    }

    function mintPrice(Tier storage self, uint256 numPeriods, bool firstMint) internal view returns (uint256) {
        return self.pricePerPeriod * numPeriods + (firstMint ? self.initialMintPrice : 0);
    }

    function hasSupply(Tier storage self) internal view returns (bool) {
        return self.maxSupply == 0 || self.numSubs < (self.maxSupply + self.numFrozenSubs);
    }

    function tokensPerSecond(Tier storage self) internal view returns (uint256) {
        return self.pricePerPeriod / self.periodDurationSeconds;
    }
}
