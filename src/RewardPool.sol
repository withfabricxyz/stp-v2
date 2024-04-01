// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {AccessControlled} from "./abstracts/AccessControlled.sol";
import {RewardPoolParams} from "./types/Index.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";
import {RewardLib} from "./libraries/RewardLib.sol";
import {IRewardPool} from "./interfaces/IRewardPool.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {Initializable} from "@solady/utils/Initializable.sol";

contract RewardPool is IRewardPool, AccessControlled, ERC20, Initializable {
    using CurrencyLib for Currency;
    using RewardLib for RewardPoolParams;

    /// @dev The total number of denominated tokens in the reward pool
    uint256 private _totalTokensIn;

    /// @dev The reward pool tokens slashed (used to calculate reward withdraws accurately)
    uint256 private _rewardPoolSlashed;

    string private _name;
    string private _symbol;

    RewardPoolParams private _params;

    Currency private _currency;

    struct Holdings {
        uint48 stakedAt;
        uint48 slashableAt;
        uint256 shares;
        uint256 totalWithdrawn;
    }

    mapping(address => Holdings) private _holders;

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_, RewardPoolParams memory params_, address currency)
        external
        initializer
    {
        _name = name_;
        _symbol = symbol_;
        _params = params_;
        _currency = Currency.wrap(currency);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function mint(address account, uint256 amount, uint256 currencyIn) external payable {
        // need to check the sender is allowed
        _currency.capture(msg.sender, currencyIn);
        _mint(account, amount);
    }

    function stake() external {
        // _holders[msg.sender].stakedAt = uint48(block.timestamp);
    }

    function unstake() external {
        // set holdings to staked
        // set the withdrawn amount to the percentage
    }

    /**
     * @notice Slash the reward points for an expired subscription after a grace period which is 50% of the purchased time
     *         Any slashable points are burned, increasing the value of remaining points.
     * @param account the account of the subscription to slash
     */
    function slashRewards(address account) external {
        // Subscription memory slasher = _subscriptions[msg.sender];
        // slasher.checkActive();

        // Subscription storage sub = _subscriptions[account];

        // // Deflate the reward points pool and account for prior reward withdrawals
        // _totalRewardPoints -= sub.rewardPoints;
        // _rewardPoolSlashed += sub.rewardsWithdrawn;

        // // If all points are slashed, move left-over funds to creator
        // if (_totalRewardPoints == 0) {
        //     _rewardPool.liquidateTo(_creatorPool);
        // }

        // emit RewardPointsSlashed(account, msg.sender, sub.rewardPoints);
        // RewardLib.slash(_RewardPoolParams, sub);
    }

    function distributeRewards(uint256 numTokens) external payable override {
        uint256 finalAmount = _currency.capture(msg.sender, numTokens);
        emit RewardsAllocated(finalAmount);
    }

    // @inheritdoc IRewardPool
    function transferRewards(address account) external override {
        Holdings storage holdings = _getHoldings(account);
        uint256 amount = _rewardBalance(holdings);
        if (amount == 0) {
            revert InsufficientRewards();
        }
        holdings.totalWithdrawn += amount;
        emit RewardTransfer(account, amount);
        _currency.transfer(account, amount);
    }

    function _getHoldings(address account) internal view returns (Holdings storage) {
        // TODO: Revert
        return _holders[account];
    }

    //     /// @dev The reward balance for a given subscription
    function _rewardBalance(Holdings memory holding) internal view returns (uint256) {
        if (holding.stakedAt == 0) {
            return 0;
        }

        // uint256 userShare = (_rewardPool.total() - _rewardPoolSlashed) * holding.shares / _totalSupply;
        // if (userShare <= sub.rewardsWithdrawn) {
        //     return 0;
        // }
        // return userShare - sub.rewardsWithdrawn;
        return 0;
    }

    //     /**
    //  * @notice The current reward multiplier used to calculate reward points on mint. This is halved every _minPurchaseSeconds and goes to 0 after N halvings.
    //  * @return multiplier the current value
    //  */
    function rewardMultiplier() public view returns (uint256 multiplier) {
        return _params.currentMultiplier();
    }

    //     /**
    //  * @notice The number of reward points allocated to all subscribers (used to calculate rewards)
    //  * @return numPoints total number of reward points
    //  */
    // function totalSupply() external view returns (uint256 numPoints) {
    //     return _totalSupply;
    // }

    // /**
    //  * @notice The balance of the reward pool (for reward withdraws)
    //  * @return numTokens number of tokens in the reward pool
    //  */
    function yieldBalance() external view returns (uint256 numTokens) {
        return _currency.balance();
    }

    function denomination() external view returns (address) {
        return Currency.unwrap(_currency);
    }

    function params() external view returns (RewardPoolParams memory) {
        return _params;
    }

    // /**
    //  * @notice The number of tokens available to withdraw from the reward pool, for a given account
    //  * @param account the account to check
    //  * @return numTokens number of tokens available to withdraw
    //  */
    function rewardBalanceOf(address account) external view returns (uint256 numTokens) {
        return _rewardBalance(_getHoldings(account));
    }
}
