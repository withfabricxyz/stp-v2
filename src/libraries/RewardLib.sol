// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {CurveParams, PoolState} from "src/types/Rewards.sol";
import {Currency, CurrencyLib} from "src/libraries/CurrencyLib.sol";
import {RewardCurveLib} from "src/libraries/RewardCurveLib.sol";

library RewardLib {
    using CurrencyLib for Currency;
    using RewardCurveLib for CurveParams;
    using RewardLib for PoolState;

    /////////////////////
    // ERRORS
    /////////////////////

    // error RewardBipsTooHigh(uint16 bips);
    // error RewardsDisabled();

    error RewardSlashingDisabled();

    error RewardSlashingNotPossible();

    error RewardSlashingNotReady(uint256 readyAt);

    function issue(PoolState storage state, address holder, uint256 numShares) internal {
        state.holders[holder].numShares += numShares;
        state.totalShares += numShares;
    }

    function issueWithCurve(PoolState storage state, address holder, uint256 numShares, uint8 curveId) internal {
        // Test size increase here
        // state.holders[holder].numShares += numShares * state.curves[curveId].currentMultiplier();
        state.issue(holder, numShares * state.curves[curveId].currentMultiplier());
    }

    function allocate(PoolState storage state, address from, uint256 amount) internal {
        state.totalRewardIngress += state.currency.capture(from, amount);
    }

    function allocateAndMint(PoolState storage state, address from, uint256 allocation, uint8 curveId) internal {
        state.totalRewardIngress += state.currency.capture(msg.sender, allocation);
        state.holders[msg.sender].numShares += allocation * state.curves[curveId].currentMultiplier();
    }

    function setSlashingPoint(PoolState storage state, address holder, uint48 slashingPoint) internal {
        state.holders[holder].slashingPoint = slashingPoint;
    }

    function rewardBalanceOf(PoolState storage state, address account) internal view returns (uint256) {
        // Holdings memory holding = _holdings[account];

        // // - 0 -> deals with burned tokens
        // uint256 burnedWithdrawTotals = 0;
        // uint256 userShare = ((_currencyCaptured - burnedWithdrawTotals) * balanceOf(account)) / totalSupply();
        // if (userShare <= _withdraws[account]) {
        //     return 0;
        // }
        // return userShare - _withdraws[account];
        // return 0;

        return state.holders[account].numShares;
    }

    /// Slash a holder's shares
    function slash() internal {
        revert RewardSlashingDisabled();
    }

}
