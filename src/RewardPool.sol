// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {AccessControlled} from "./abstracts/AccessControlled.sol";
import {CurveParams, RewardPoolParams, PoolState, IssueParams, Holder, PoolDetailView, HolderDetailView, CurveDetailView} from "./types/Rewards.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";
import {RewardLib} from "./libraries/RewardLib.sol";
import {RewardCurveLib} from "./libraries/RewardCurveLib.sol";
import {TokenRecovery} from "./abstracts/TokenRecovery.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";


contract RewardPool is AccessControlled, Initializable, TokenRecovery, Multicallable {
    using CurrencyLib for Currency;
    using RewardCurveLib for CurveParams;
    using RewardLib for PoolState;

    /// @dev The minter role is granted to contracts which are allowed to mint tokens with funds
    uint16 public constant ROLE_MINTER = 1;

    /// @dev The creator role is granted by the factory to the creator of the pool .... TODO: what does this mean?
    uint16 public constant ROLE_CREATOR = 2;

    /// @dev The pool state (holders, supply, counts, etc)
    PoolState private _state;

    /// @dev RewardPools are cloned, so the constructor is disabled
    constructor() {
        _disableInitializers();
    }

    function initialize(RewardPoolParams memory params, CurveParams memory curve) external initializer {
        _setOwner(msg.sender); // TODO: Creator?
        _state.currency = Currency.wrap(params.currencyAddress);
        _state.curves[0] = curve;
    }

    //////////////////////////////
    // External actions
    //////////////////////////////

    /**
     * @notice Fallback function to allocate rewards for stakers
     */
    receive() external payable {
        yieldRewards(msg.value);
    }

    /**
     * @notice Mint tokens to an account without payment (used for migrations, tips, etc)
     */
    function adminMint(address account, uint256 amount) external {
        // _checkAdmin();
        _checkRoles(ROLE_CREATOR);
        _state.issue(account, amount);
    }

    function issue(IssueParams calldata params) external payable {
        _checkRoles(ROLE_MINTER);
        _state.allocate(msg.sender, params.allocation);
        _state.issueWithCurve(params.holder, params.numShares, params.curveId);
        _state.setSlashingPoint(params.holder, params.slashingThreshold);
    }

    /**
     * @notice Allocate rewards to the pool in the denominated currency
     * @param amount the amount of tokens (native or ERC20) to allocate
     */
    function yieldRewards(uint256 amount) public payable {
        _state.allocate(msg.sender, amount);
        // emit Yield(amount);
    }

    function createCurve(CurveParams memory curve) external {
        _checkRoles(ROLE_CREATOR); // TODO
        _state.curves[curve.id] = curve;
    }


    // @inheritdoc IRewardPool
    // transferRewardsFor?
    function transferRewardsFor(address account) public {
        // _state.transferRewardsFor(account);
        // uint256 amount = rewardBalanceOf(account);
        // if (amount == 0) {
        //     revert InsufficientRewards();
        // }
        // if (!_staked[account]) {
        //     revert AccountNotStaked();
        // }

        // _withdraws[account] += amount;

        // emit RewardTransfer(account, amount);
        // _currency.transfer(account, amount);
        revert("no");
    }

    //////////////////////////////
    // View functions
    //////////////////////////////

    function poolDetail() external view returns (PoolDetailView memory) {
        return PoolDetailView({
            totalShares: _state.totalShares,
            currencyAddress: Currency.unwrap(_state.currency),
            numCurves: 1,
            balance: _state.currency.balance()
        });
    }

    function curveDetail(uint8 curve) external view returns (CurveDetailView memory) {
        return CurveDetailView({
            currentMultiplier: _state.curves[curve].currentMultiplier(),
            flattenTimestamp: 0
        });
    }

    function holderDetail(address account) external view returns (HolderDetailView memory) {
        return HolderDetailView({
            numShares: _state.holders[account].numShares,
            rewardsWithdrawn: _state.holders[account].rewardsWithdrawn,
            slashingPoint: _state.holders[account].slashingPoint
        });
    }

    /**
     * @notice Fetch the base token balance for an account (0 if not staked)
     * @param account the account to check
     * @return numTokens number of tokens available to withdraw
     */
    function rewardBalanceOf(address account) public view returns (uint256 numTokens) {
        return _state.rewardBalanceOf(account);
    }

}
