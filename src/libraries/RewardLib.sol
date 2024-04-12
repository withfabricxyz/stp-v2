// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Currency, CurrencyLib} from "src/libraries/CurrencyLib.sol";
import {RewardCurveLib} from "src/libraries/RewardCurveLib.sol";
import {CurveParams, Holder} from "src/types/Rewards.sol";

library RewardLib {
    using CurrencyLib for Currency;
    using RewardCurveLib for CurveParams;
    using RewardLib for State;

    struct State {
        uint256 totalShares;
        uint256 totalRewardEgress;
        uint256 totalRewardIngress;
        uint256 pointsPerShare;
        mapping(address => Holder) holders;
        mapping(uint8 => CurveParams) curves;
    }

    uint256 private constant pointsMultiplier = 2 ** 64;

    /////////////////////
    // EVENTS
    /////////////////////
    event RewardsAllocated(uint256 amount);

    event RewardsClaimed(address indexed account, uint256 amount);

    event SharesIssued(address indexed account, uint256 numShares);

    event SharesBurned(address indexed account, uint256 numShares);

    /////////////////////
    // ERRORS
    /////////////////////

    error NoRewardsToClaim();

    error AllocationWithoutShares();

    error NoSharesToBurn();

    /// @dev Issue shares to a holder
    function issue(State storage state, address holder, uint256 numShares) internal {
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
        state.pointsPerShare += (amount * pointsMultiplier) / state.totalShares;
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
            uint256(int256(state.pointsPerShare * holder.numShares) + holder.pointsCorrection) / pointsMultiplier;
        return exposure - holder.rewardsWithdrawn;
    }

    /// @dev Burn shares of a holder and adjust the points per share
    function burn(State storage state, address account) internal {
        uint256 numShares = state.holders[account].numShares;
        if (numShares == 0) revert NoSharesToBurn();
        state.totalShares -= numShares;
        state.pointsPerShare = (state.totalRewardIngress * pointsMultiplier) / state.totalShares;
        delete state.holders[account];
        emit SharesBurned(account, numShares);
    }
}
