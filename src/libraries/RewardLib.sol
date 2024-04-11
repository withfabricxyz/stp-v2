// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Currency, CurrencyLib} from "src/libraries/CurrencyLib.sol";
import {RewardCurveLib} from "src/libraries/RewardCurveLib.sol";
import {CurveParams, Holder, PoolState} from "src/types/Rewards.sol";

library RewardLib {
    using CurrencyLib for Currency;
    using RewardCurveLib for CurveParams;
    using RewardLib for PoolState;

    uint256 private constant pointsMultiplier = 2 ** 64;

    /////////////////////
    // EVENTS
    /////////////////////
    event RewardsAllocated(uint256 amount);

    event RewardsClaimed(address indexed account, uint256 amount);

    event AccountSlashed(address indexed account, uint256 numShares);

    /////////////////////
    // ERRORS
    /////////////////////

    error NoRewardsToClaim();

    error NoSupply();

    error RewardSlashingNotPossible();

    error RewardSlashingNotReady(uint256 readyAt);

    function issue(PoolState storage state, address holder, uint256 numShares) internal {
        state.totalShares += numShares;
        state.holders[holder].numShares += numShares;
        state.holders[holder].pointsCorrection -= int256(state.pointsPerShare * numShares);
    }

    function issueWithCurve(PoolState storage state, address holder, uint256 numShares, uint8 curveId) internal {
        state.issue(holder, numShares * state.curves[curveId].currentMultiplier());
    }

    function allocate(PoolState storage state, address from, uint256 amount) internal {
        if (state.totalShares == 0) revert NoSupply();

        uint256 captured = state.currency.capture(from, amount);

        state.pointsPerShare += (captured * pointsMultiplier) / state.totalShares;
        state.totalRewardIngress += captured;

        emit RewardsAllocated(captured);
    }

    function setSlashingPoint(PoolState storage state, address holder, uint48 slashingPoint) internal {
        state.holders[holder].slashingPoint = slashingPoint;
    }

    function claimRewards(PoolState storage state, address account) internal {
        uint256 amount = state.rewardBalanceOf(account);
        if (amount == 0) revert NoRewardsToClaim();
        state.holders[account].rewardsWithdrawn += amount;
        state.totalRewardEgress += amount;
        emit RewardsClaimed(account, amount);
        state.currency.transfer(account, amount);
    }

    function rewardBalanceOf(PoolState storage state, address account) internal view returns (uint256) {
        if (state.totalShares == 0) return 0;
        Holder memory holder = state.holders[account];
        uint256 accumlated =
            uint256(int256(state.pointsPerShare * holder.numShares) + holder.pointsCorrection) / pointsMultiplier;
        return accumlated - holder.rewardsWithdrawn;
    }

    // TODO: Reconcile function

    /// Slash a holder's shares
    function burn(PoolState storage state, address account) internal {
        // TODO: Check slashability

        uint256 numShares = state.holders[account].numShares;
        state.totalShares -= numShares;
        state.pointsPerShare = (state.totalRewardIngress * pointsMultiplier) / state.totalShares;

        delete state.holders[account];

        // emit Burn();
        emit AccountSlashed(account, numShares);
    }
}
