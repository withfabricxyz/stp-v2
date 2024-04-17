// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {FeeParams, InitParams, Subscription, Tier} from "src/types/Index.sol";
import {CurveParams, RewardParams} from "src/types/Rewards.sol";

interface ISTPV2 {
    //////////////////
    // ERRORS
    //////////////////

    /// @notice Error when the owner is invalid
    error InvalidOwner();

    /// @notice Error when the token params are invalid
    error InvalidTokenParams();

    /// @notice Error when the fee params are invalid
    error InvalidFeeParams();

    /// @notice Error when the reward params are invalid
    error InvalidRewardParams();

    /// @notice Error when a transfer fails due to the recipient having a subscription
    error TransferToExistingSubscriber();

    /// @notice Error when the balance is insufficient for a transfer
    error InsufficientBalance();

    /// @notice Error when slashing fails due to constraints
    error NotSlashable();

    //////////////////
    // EVENTS
    //////////////////

    /// @dev Emitted when the owner withdraws available funds
    event Withdraw(address indexed account, uint256 tokensTransferred);

    /// @dev Emitted when the creator tops up the contract balance on refund
    event TopUp(uint256 tokensIn);

    /// @dev Emitted when the fees are transferred to the collector
    event FeeTransfer(address indexed to, uint256 tokensTransferred);

    /// @dev Emitted when the fee collector is updated
    event FeeCollectorChange(address indexed collector);

    /// @dev Emitted when a referral fee is paid out
    event ReferralPayout(
        uint256 indexed tokenId, address indexed referrer, uint256 indexed referralId, uint256 rewardAmount
    );

    /// @dev Emitted when the supply cap is updated
    event GlobalSupplyCapChange(uint256 supplyCap);

    /// @dev Emitted when the transfer recipient is updated
    event TransferRecipientChange(address indexed recipient);

    function initialize(
        InitParams memory params,
        Tier memory tier,
        RewardParams memory rewards,
        CurveParams memory curve,
        FeeParams memory fees
    ) external;

    //////////////////
    // MINTING
    //////////////////

    /**
     * @notice Mint or renew a subscription for sender
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mint(uint256 numTokens) external payable;

    /**
     * @notice Mint or renew a subscription for a specific account. Intended for automated renewals.
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mintFor(address account, uint256 numTokens) external payable;

    //~~~~~~~~~~~ V2 ~~~~~~~~~~~~//

    //////////////////
    // ADMIN
    //////////////////

    /**
     * @notice Create a new Tier
     * @param params The tier parameters
     */
    function createTier(Tier memory params) external;

    /**
     * @notice Grant time to an account on a specific tier
     * @param account the account to grant time to
     * @param numSeconds the number of seconds to grant
     * @param tierId the id of the tier to assign them to if they are not on a tier
     */
    function grantTime(address account, uint48 numSeconds, uint16 tierId) external;

    /**
     * @notice Revoke time from an account
     * @param account the account to revoke time from
     */
    function revokeTime(address account) external;

    // function mintPrice(address account, uint8 tierId, uint32 numPeriods) external view returns (uint256);

    /**
     * @notice Mark subscription as inactive
     * @dev This checks the subscription and moves it to the inactive tier (tierId = 0) if it has expired
     * @param account the subscriber account to mark as inactive
     */
    function deactivateSubscription(address account) external;

    /**
     * @notice Get the balance of an account in a specific tier
     * @param tierId the tier id filter
     * @param account the account to check the balance of
     * @return balance the balance of the account in the specified tier
     */
    function tierBalanceOf(uint16 tierId, address account) external view returns (uint256 balance);

    // function feeDetails() external view returns (FeeParams memory);
    // function setDefaultTier(uint16 tierId) external; ???

    //////////////////
    // Rewards
    //////////////////

    // function pools() external view returns (Pool memory creator, Pool memory rewards, Pool memory fees);
    // function rewardDetails() external view returns (CurveParams memory);

    /**
     * @notice Distribute rewards to subscribers
     * @param numTokens the amount of ERC20 or native tokens to add to the reward pool
     */
    // function distributeRewards(uint256 numTokens) external payable;

    /**
     * @notice Transfer the reward balance for a specific account to that account
     */
    // function transferRewardsFor(address account) external;
}
