// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RewardParams} from "src/types/InitParams.sol";

library RewardLib {
    /// @dev The maximum reward factor (limiting this prevents overflow)
    uint256 private constant MAX_REWARD_FACTOR = 2 ** 64;

    /// @dev Maximum basis points (100%)
    uint16 private constant MAX_BIPS = 10000;

    /////////////////////
    // ERRORS
    /////////////////////
    error RewardBipsTooHigh(uint16 bips);

    error RewardInvalidFormula();

    function validate(RewardParams memory self) internal view returns (RewardParams memory) {
        if (self.bips > MAX_BIPS) {
            revert RewardBipsTooHigh(self.bips);
        }

        // require(self.bips <= MAX_BIPS, "Reward bps too high");
        require(self.numPeriods <= MAX_REWARD_FACTOR, "Reward halvings too high");
        if (self.bips > 0) {
            if (self.numPeriods == 0 && self.minMultiplier == 0) {
                revert RewardInvalidFormula();
            }
        }

        if (self.startTimestamp == 0) {
            self.startTimestamp = uint48(block.timestamp);
        }

        return self;
    }

    function passedHalvings(RewardParams memory self) internal view returns (uint256) {
        return (block.timestamp - self.startTimestamp) / self.periodSeconds;
    }

    function currentMultiplier(RewardParams memory self) internal view returns (uint256 multiplier) {
        if (self.numPeriods == 0) {
            return 0;
        }
        uint256 halvings = passedHalvings(self);
        if (halvings > self.numPeriods) {
            return self.minMultiplier;
        }
        return (2 ** self.numPeriods) / (2 ** halvings);
    }
}
