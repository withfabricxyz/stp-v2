// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {RewardCurveParams, Subscription} from "src/types/Index.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";

// struct RewardCurveParams {
// }

struct TmpRewardCurveParams {
    uint48 adminControlEndDate;
}

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

    function validate(RewardCurveParams memory self) internal view returns (RewardCurveParams memory) {
        if (uint256(self.formulaBase) ** self.numPeriods > MAX_MULTIPLIER) revert RewardFormulaInvalid();
        if (self.numPeriods == 0 && self.minMultiplier == 0) revert RewardFormulaInvalid();

        if (self.startTimestamp == 0) {
            self.startTimestamp = uint48(block.timestamp);
        }

        return self;
    }

    function currentMultiplier(RewardCurveParams memory self) internal view returns (uint256 multiplier) {
        if (self.numPeriods == 0) {
            return self.minMultiplier;
        }
        uint256 periods = surpassedPeriods(self);
        if (periods > self.numPeriods) {
            return self.minMultiplier;
        }
        return (uint256(self.formulaBase) ** self.numPeriods) / (uint256(self.formulaBase) ** periods);
    }

    function surpassedPeriods(RewardCurveParams memory self) private view returns (uint256) {
        return (block.timestamp - self.startTimestamp) / self.periodSeconds;
    }
}
