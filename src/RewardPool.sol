// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {AccessControlled} from "./abstracts/AccessControlled.sol";
import {RewardCurveParams} from "./types/Rewards.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";
import {RewardLib} from "./libraries/RewardLib.sol";
import {IRewardPool} from "./interfaces/IRewardPool.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {Initializable} from "@solady/utils/Initializable.sol";

contract RewardPool is IRewardPool, AccessControlled, ERC20, Initializable {
    using CurrencyLib for Currency;
    using RewardLib for RewardCurveParams;

    /// @dev The minter role is granted to contracts which are allowed to mint tokens with funds
    uint16 public constant ROLE_MINTER = 1;

    /// @dev The creator role is granted by the factory to the creator of the pool .... TODO: what does this mean?
    uint16 public constant ROLE_CREATOR = 2;

    /// uint16 private constant ROLE_PARTNER = 2;

    uint256 private _currencyCaptured;

    /// @dev The ERC20 token name
    string private _name;

    /// @dev The ERC20 token symbol
    string private _symbol;

    RewardCurveParams private _params;

    /// @dev The base currency for the reward pool (what staked withdraws receive)
    Currency private _currency;

    /// @dev The number of base tokens withdrawn by an account (used to calculate reward withdraws accurately)
    mapping(address => uint256) private _withdraws;

    /// @dev Staking status for accounts (staked = withdraws are possible and transfers are not)
    mapping(address => bool) private _staked;

    /// @dev RewardPools are cloned, so the constructor is disabled
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_, RewardCurveParams memory params_, address currency)
        external
        initializer
    {
        _name = name_;
        _symbol = symbol_;
        _params = params_;
        _currency = Currency.wrap(currency);
        _setOwner(msg.sender); // Factory is the owner
            // set the role for the creator
    }

    //////////////////////////////
    // External actions
    //////////////////////////////

    /**
     * @notice Fallback function to allocate rewards for stakers
     */
    receive() external payable {
        distributeRewards(msg.value);
    }

    /**
     * @notice Mint tokens to an account without payment (used for migrations, etc)
     */
    function adminMint(address account, uint256 amount) external {
        // _checkAdmin();
        _checkRoles(ROLE_CREATOR);
        _mint(account, amount);
    }

    function mint(address account, uint256 amount, uint256 payment) external payable {
        _checkRoles(ROLE_MINTER);

        // if secondary multiplier are not allowed, set to 1
        // if (!_params.secondaryMultiplierAllowed() && multiplier > 1) {
        //   multiplier = 1;
        // }

        _capture(payment);
        _mint(account, amount * rewardMultiplier());
    }

    // allocateRewards?
    function distributeRewards(uint256 numTokens) public payable override {
        uint256 finalAmount = _capture(numTokens);
        emit RewardsAllocated(finalAmount);
    }

    // @inheritdoc IRewardPool
    // transferRewardsFor?
    function transferRewardsFor(address account) public override {
        // TODO: _checkOwnerOrRoles(ROLE_MEOW) -> Factory can transfer rewards for accounts (in bulk)
        uint256 amount = rewardBalanceOf(account);
        if (amount == 0) {
            revert InsufficientRewards();
        }
        if (!_staked[account]) {
            revert AccountNotStaked();
        }

        _withdraws[account] += amount;

        emit RewardTransfer(account, amount);
        _currency.transfer(account, amount);
    }

    function stake() external {
        address account = msg.sender;

        if (_staked[account]) {
            revert("Account already staked");
        }
        if (balanceOf(account) == 0) {
            revert("Cannot stake with balance");
        }
        _staked[account] = true;

        // Prevent immediate withdraws
        _withdraws[account] = rewardBalanceOf(account);
        // emit TokensStaked(account, amount);
    }

    function unstake() external {
        address account = msg.sender;
        if (!_staked[account]) {
            revert AccountNotStaked();
        }
        if (balanceOf(account) == 0) {
            revert("Cannot unstake with balance");
        }
        _staked[account] = false;

        // Update counters?
        // Transfer rewards?
        // if(rewardBalanceOf(account) > 0) {
        //     transferRewardsFor(account);
        // }

        // emit TokensUnstaked(account, amount);
    }

    //////////////////////////////
    // View functions
    //////////////////////////////

    /// @inheritdoc ERC20
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @inheritdoc ERC20
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice The current reward multiplier used to calculate reward points on mint. This may decay based on the curve configuration.
     * @return multiplier the current value
     */
    function rewardMultiplier() public view returns (uint256 multiplier) {
        return _params.currentMultiplier();
    }

    function balance() external view returns (uint256 numTokens) {
        return _currency.balance();
    }

    function currency() external view returns (address) {
        return Currency.unwrap(_currency);
    }

    function params() external view returns (RewardCurveParams memory) {
        return _params;
    }

    /**
     * @notice Fetch the base token balance for an account (0 if not staked)
     * @param account the account to check
     * @return numTokens number of tokens available to withdraw
     */
    function rewardBalanceOf(address account) public view returns (uint256 numTokens) {
        // - 0 -> deals with burned tokens
        uint256 burnedWithdrawTotals = 0;
        uint256 userShare = ((_currencyCaptured - burnedWithdrawTotals) * balanceOf(account)) / totalSupply();
        if (userShare <= _withdraws[account]) {
            return 0;
        }
        return userShare - _withdraws[account];
    }

    //////////////////////////////
    // Internal logic
    //////////////////////////////

    function _capture(uint256 tokens) private returns (uint256 finalAmount) {
        finalAmount = _currency.capture(msg.sender, tokens);
        _currencyCaptured += finalAmount;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (balanceOf(to) == 0) {
            _staked[to] = true;
        }
        // prevent transfers if staked
        // if a new account, immediately stake and give them access to all liquidity
    }
}
