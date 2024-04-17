// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {RewardCurveLib} from "src/libraries/RewardCurveLib.sol";
import {CurveParams, Holder} from "src/types/Rewards.sol";

/// @dev Library for reward tracking and distribution
library RewardLib {
    using RewardCurveLib for CurveParams;
    using RewardLib for State;

    struct State {
        /// @dev The number of reward curves
        uint8 numCurves;
        /// @dev The total number of outstanding shares
        uint256 totalShares;
        /// @dev The total amount of tokens which have been allocated to the pool
        uint256 totalRewardEgress;
        /// @dev The total amount of tokens which have been claimed from the pool
        uint256 totalRewardIngress;
        /// @dev The total points per share (used for reward calculations)
        uint256 pointsPerShare;
        mapping(address => Holder) holders;
        mapping(uint8 => CurveParams) curves;
    }

    /// @dev Reduces precision loss for reward calculations
    uint256 private constant PRECISION_COEFFICIENT = 2 ** 64;

    /////////////////////
    // EVENTS
    /////////////////////

    /// @dev Rewards were allocated to the pool (currency ingress)
    event RewardsAllocated(uint256 amount);

    /// @dev Rewards were claimed for a given account (currency egress)
    event RewardsClaimed(address indexed account, uint256 amount);

    /// @dev Shares were issued (dilution)
    event SharesIssued(address indexed account, uint256 numShares);

    /// @dev Shares were burned (increases value of remaining shares)
    event SharesBurned(address indexed account, uint256 numShares);

    /// @dev A new reward curve was created
    event CurveCreated(uint8 curveId);

    /////////////////////
    // ERRORS
    /////////////////////

    /// @dev Error when trying to claim rewards with none available
    error NoRewardsToClaim();

    /// @dev Error when trying to allocate rewards without any shares
    error AllocationWithoutShares();

    /// @dev Error when trying to burn shares of a holder with none
    error NoSharesToBurn();

    /// @dev Create a new reward curve (starting at id 0)
    function createCurve(State storage state, CurveParams memory curve) internal {
        curve.validate();
        emit CurveCreated(state.numCurves);
        state.curves[state.numCurves++] = curve;
    }

    /// @dev Issue shares to a holder
    function issue(State storage state, address holder, uint256 numShares) internal {
        if (numShares == 0) return;
        state.totalShares += numShares;
        state.holders[holder].numShares += numShares;
        state.holders[holder].pointsCorrection -= int256(state.pointsPerShare * numShares);
        emit SharesIssued(holder, numShares);
    }

    /// @dev Issue shares to a holder with a curve multiplier
    function issueWithCurve(State storage state, address holder, uint256 numShares, uint8 curveId) internal {
        state.issue(holder, numShares * state.curves[curveId].currentMultiplier());
    }

    /// @dev Allocate rewards to the pool for holders to claim (capture should be done separately)
    function allocate(State storage state, uint256 amount) internal {
        if (state.totalShares == 0) revert AllocationWithoutShares();
        state.pointsPerShare += (amount * PRECISION_COEFFICIENT) / state.totalShares;
        state.totalRewardIngress += amount;
        emit RewardsAllocated(amount);
    }

    /// @dev Claim rewards for a holder (transfer should be done separately)
    function claimRewards(State storage state, address account) internal returns (uint256 amount) {
        amount = state.rewardBalanceOf(account);
        if (amount == 0) revert NoRewardsToClaim();
        state.holders[account].rewardsWithdrawn += amount;
        state.totalRewardEgress += amount;
        emit RewardsClaimed(account, amount);
    }

    /// @dev Calculate the reward balance of a holder
    function rewardBalanceOf(State storage state, address account) internal view returns (uint256) {
        if (state.totalShares == 0) return 0;
        Holder memory holder = state.holders[account];
        uint256 exposure =
            uint256(int256(state.pointsPerShare * holder.numShares) + holder.pointsCorrection) / PRECISION_COEFFICIENT;
        return exposure - holder.rewardsWithdrawn;
    }

    /// @dev Burn shares of a holder and adjust the points per share
    function burn(State storage state, address account) internal {
        uint256 numShares = state.holders[account].numShares;
        if (numShares == 0) revert NoSharesToBurn();
        state.totalShares -= numShares;
        if (state.totalShares > 0) {
            state.pointsPerShare = (state.totalRewardIngress * PRECISION_COEFFICIENT) / state.totalShares;
        }
        delete state.holders[account];
        emit SharesBurned(account, numShares);
    }

    /// @dev Calculate the total balance of the pool
    function balance(State storage state) internal view returns (uint256) {
        return state.totalRewardIngress - state.totalRewardEgress;
    }
}
