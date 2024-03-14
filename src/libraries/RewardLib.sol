// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RewardParams, Subscription} from "src/types/Index.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";

library RewardLib {
    /// @dev The maximum reward factor (limiting this prevents overflow)
    uint256 private constant MAX_MULTIPLIER = 2 ** 64;

    /// @dev Maximum basis points (100%)
    uint16 private constant MAX_BIPS = 10_000;

    /////////////////////
    // ERRORS
    /////////////////////

    error RewardBipsTooHigh(uint16 bips);

    error RewardFormulaInvalid();

    error RewardsDisabled();

    error RewardSlashingDisabled();

    error RewardSlashingNotPossible();

    error RewardSlashingNotReady(uint256 readyAt);

    function validate(RewardParams memory self) internal view returns (RewardParams memory) {
        if (self.bips > MAX_BIPS) {
            revert RewardBipsTooHigh(self.bips);
        }

        if (uint256(self.formulaBase) ** self.numPeriods > MAX_MULTIPLIER) {
            revert RewardFormulaInvalid();
        }

        if (self.bips > 0) {
            if (self.numPeriods == 0 && self.minMultiplier == 0) {
                revert RewardFormulaInvalid();
            }
        }

        if (self.startTimestamp == 0) {
            self.startTimestamp = uint48(block.timestamp);
        }

        return self;
    }

    function currentMultiplier(RewardParams memory self) internal view returns (uint256 multiplier) {
        if (self.numPeriods == 0) {
            return self.minMultiplier;
        }
        uint256 periods = surpassedPeriods(self);
        if (periods > self.numPeriods) {
            return self.minMultiplier;
        }
        return (uint256(self.formulaBase) ** self.numPeriods) / (uint256(self.formulaBase) ** periods);
    }

    function rewardValue(RewardParams memory self, uint256 numTokens) internal pure returns (uint256 tokens) {
        return (numTokens * self.bips) / MAX_BIPS;
    }

    function slash(RewardParams memory self, Subscription storage subscription) internal {
        if (self.bips == 0) {
            revert RewardsDisabled();
        }

        if (!self.slashable) {
            revert RewardSlashingDisabled();
        }

        if (subscription.rewardPoints == 0) {
            revert RewardSlashingNotPossible();
        }

        uint256 slashPoint = SubscriptionLib.expiresAt(subscription) + self.slashGracePeriod;
        if (block.timestamp <= slashPoint) {
            revert RewardSlashingNotReady(slashPoint);
        }

        subscription.rewardPoints = 0;
        subscription.rewardsWithdrawn = 0;
    }

    function surpassedPeriods(RewardParams memory self) private view returns (uint256) {
        return (block.timestamp - self.startTimestamp) / self.periodSeconds;
    }
}
