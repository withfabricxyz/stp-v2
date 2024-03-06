// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Tier} from "../types/Tier.sol";

/// @dev The initialization parameters for a subscription token
library TierLib {
    /////////////////////
    // ERRORS
    /////////////////////

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
