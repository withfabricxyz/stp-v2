// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {CurveParams} from "src/types/Rewards.sol";

/// @dev Library for reward curve calculations
library RewardCurveLib {
    /// @dev The maximum reward factor (limiting this prevents overflow)
    uint256 private constant MAX_MULTIPLIER = 2 ** 64;

    /// @dev Error when the curve configuration is invalid (e.g. multiplier too high)
    error InvalidCurve();

    /// @dev Validate the curve configuration (and set the startTimestamp if not set)
    function validate(CurveParams memory curve) internal view returns (CurveParams memory) {
        // Reduce the risk of overflow by limiting the multiplier
        if (uint256(curve.formulaBase) ** curve.numPeriods > MAX_MULTIPLIER) revert InvalidCurve();
        if (curve.numPeriods == 0 && curve.minMultiplier == 0) revert InvalidCurve();
        if (curve.startTimestamp > block.timestamp) revert InvalidCurve();

        if (curve.startTimestamp == 0) curve.startTimestamp = uint48(block.timestamp);

        return curve;
    }

    /// @dev Calculate the current multiplier for the curve: base ^ (numPeriods - periods)
    ///      If the curve has no decay, the multiplier will be the minMultiplier
    function currentMultiplier(CurveParams memory curve) internal view returns (uint256 multiplier) {
        if (curve.numPeriods == 0) return curve.minMultiplier;

        uint256 periods = surpassedPeriods(curve);
        if (periods > curve.numPeriods) return curve.minMultiplier;

        return uint256(curve.formulaBase) ** (curve.numPeriods - periods);
    }

    /// @dev Calculate the timestamp at which the curve flattens (minMultiplier is reached)
    function flattensAt(CurveParams memory curve) internal pure returns (uint48) {
        return curve.startTimestamp + uint48((curve.numPeriods + 1) * curve.periodSeconds);
    }

    /// @dev How many periods have passed, so we can compute the current multiplier
    function surpassedPeriods(CurveParams memory curve) private view returns (uint256) {
        return (block.timestamp - curve.startTimestamp) / curve.periodSeconds;
    }
}
