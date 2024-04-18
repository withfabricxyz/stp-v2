// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {CurveParams} from "src/types/Rewards.sol";

/// @dev Library for reward curve calculations
library RewardCurveLib {
    /// @dev Calculate the current multiplier for the curve: base ^ (numPeriods - periods)
    ///      If the curve has no decay, the multiplier will be the minMultiplier
    function currentMultiplier(CurveParams memory curve) internal view returns (uint256 multiplier) {
        if (curve.numPeriods == 0) return curve.minMultiplier;

        uint256 periods = surpassedPeriods(curve);
        if (periods > curve.numPeriods) return curve.minMultiplier;

        return uint256(curve.formulaBase) ** (curve.numPeriods - periods);
    }

    /// @dev How many periods have passed, so we can compute the current multiplier
    function surpassedPeriods(CurveParams memory curve) private view returns (uint256) {
        return (block.timestamp - curve.startTimestamp) / curve.periodSeconds;
    }
}
