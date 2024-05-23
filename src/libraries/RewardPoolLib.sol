// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.25;

import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";

import {RewardCurveLib} from "src/libraries/RewardCurveLib.sol";
import {CurveParams, Holder} from "src/types/Rewards.sol";

/// @dev Library for reward tracking and distribution
///
///      This library is designed to issues shares to holders based on a multiplier calculated
///      via a reward curve multiplied by allocated currency. Each holder effectively has a percentage
///      of the total reward pool which allows them to claim rewards (currency) based on their
///      share of the pool and time of issuance.
///
///      The reward curve is defined by a set of parameters which determine the multiplier at any given time.
///
///      Because the reward curves can be flat or decaying, earlier holders may have a higher multiplier
///      than later holders. This is useful for incentivizing early participation in a protocol.
///
///      Additionally, there are slashing (burning) mechanisms which can be used to reduce the total
///      number of shares. With STP, holders are slashable if the creator allows it at deployment AND
///      the holder is no longer an active subscriber. Holders are paid out their rewards before losing shares.
///
///      Note: Due to the nature of curves and allocation, the order of issuance matters. Example:
///      - Contract deployed
///      - Alice allocates 100 tokens and now owns 100% of the shares
///        - Alice has 100 claimable tokens
///      - Bob allocates 100 tokens and now owns 1/2 of the shares, alice 1/2
///        - Alice has 150 claimable tokens
///        - Bob has 50 claimable tokens
///      - Charlie allocates 100 tokens and now owns 1/3 of the shares, alice 1/3, bob 1/3
///        - Alice has ~183.33 claimable tokens
///        - Bob has ~83.33 claimable tokens
///        - Charlie has ~33.33 claimable tokens
///      - Creator issues 100 shares to doug, all parties now own 1/4 of the shares
///        - Alice has ~183.33 claimable tokens
///        - Bob has ~83.33 claimable tokens
///        - Charlie has ~33.33 claimable tokens
///        - Doug has ~0 claimable tokens
library RewardPoolLib {
    using RewardCurveLib for CurveParams;
    using RewardPoolLib for State;
    using SafeCastLib for uint256;

    struct State {
        /// @dev The number of reward curves
        uint8 numCurves;
        /// @dev The total number of outstanding shares
        uint256 totalShares;
        /// @dev The total amount of tokens which have been allocated to the pool
        uint256 totalRewardIngress;
        /// @dev The total amount of tokens which have been claimed from the pool
        uint256 totalRewardEgress;
        /// @dev The total points per share (used for reward calculations)
        uint256 pointsPerShare;
        /// @dev The holders of the pool by account
        mapping(address => Holder) holders;
        /// @dev The reward curves by id
        mapping(uint8 => CurveParams) curves;
    }

    /// @dev Reduces precision loss for reward calculations
    uint256 private constant PRECISION_FACTOR = 2 ** 96;

    /// @dev The maximum reward factor (this limits overflow probability)
    uint256 private constant MAX_MULTIPLIER = 2 ** 36;

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

    /// @dev Error when the curve configuration is invalid (e.g. multiplier too high)
    error InvalidCurve();

    /// @dev Error when the account is invalid (0 address)
    error InvalidHolder();

    /// @dev Create a new reward curve (starting at id 0)
    function createCurve(State storage state, CurveParams memory curve) internal {
        if (curve.startTimestamp == 0) curve.startTimestamp = uint48(block.timestamp);
        if (curve.numPeriods == 0 && curve.minMultiplier == 0) revert InvalidCurve();
        if (curve.startTimestamp > block.timestamp) revert InvalidCurve();
        if (curve.currentMultiplier() > MAX_MULTIPLIER) revert InvalidCurve();

        // curve.validate();
        emit CurveCreated(state.numCurves);
        state.curves[state.numCurves++] = curve;
    }

    /// @dev Issue shares to a holder
    function issue(State storage state, address holder, uint256 numShares) internal {
        if (numShares == 0) return;
        if (holder == address(0)) revert InvalidHolder();
        state.totalShares += numShares;
        state.holders[holder].numShares += numShares;
        state.holders[holder].pointsCorrection -= (state.pointsPerShare * numShares).toInt256();
        emit SharesIssued(holder, numShares);
    }

    /// @dev Issue shares to a holder with a curve multiplier
    function issueWithCurve(State storage state, address holder, uint256 numShares, uint8 curveId) internal {
        state.issue(holder, numShares * state.curves[curveId].currentMultiplier());
    }

    /// @dev Allocate rewards to the pool for holders to claim (capture should be done separately)
    function allocate(State storage state, uint256 amount) internal {
        if (state.totalShares == 0) revert AllocationWithoutShares();
        state.pointsPerShare += (amount * PRECISION_FACTOR) / state.totalShares;
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
            uint256((state.pointsPerShare * holder.numShares).toInt256() + holder.pointsCorrection) / PRECISION_FACTOR;
        return exposure - holder.rewardsWithdrawn;
    }

    /// @dev Claim rewards and burn shares of a holder.
    ///      Note: Ensure the caller transfers the reward amount to the holder
    function burn(State storage state, address account) internal returns (uint256 transferAmount) {
        uint256 numShares = state.holders[account].numShares;
        if (numShares == 0) revert NoSharesToBurn();
        if (state.rewardBalanceOf(account) > 0) {
            // The amount of tokens to transfer to the holder after calling burn
            transferAmount = state.claimRewards(account);
        }
        state.totalShares -= numShares;
        delete state.holders[account];
        emit SharesBurned(account, numShares);
    }

    /// @dev Calculate the total balance of the pool
    function balance(State storage state) internal view returns (uint256) {
        return state.totalRewardIngress - state.totalRewardEgress;
    }
}
