// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Subscription, Tier} from "src/types/Index.sol";

interface ISubscriptionTokenV2 {
    //////////////////
    // ERRORS
    //////////////////

    // TODO: Doc
    error InvalidOwner();
    error InvalidName();
    error InvalidSymbol();
    error InvalidContractUri();
    error InvalidFeeParams();
    error InvalidBps();
    error InvalidRewardParams();
    error InvalidAccount();
    error InvalidTransfer();
    error Unauthorized();
    error ReferralExists(uint256 code);
    error InvalidRecovery();
    error TransferFailed();
    error GlobalSupplyLimitExceeded();

    //////////////////
    // EVENTS
    //////////////////

    /// @dev A new tier has been created
    event TierCreated(uint16 tierId);

    /// @dev The tier is paused
    event TierPaused(uint16 tierId);

    /// @dev The tier is unpaused
    event TierUnpaused(uint16 tierId);

    /// @dev The tier price has changed
    event TierPriceChange(uint16 tierId, uint256 pricePerPeriod);

    /// @dev the supply cap has changed
    event TierSupplyCapChange(uint16 tierId, uint32 newCap);

    /// @dev Emitted when the owner withdraws available funds
    event Withdraw(address indexed account, uint256 tokensTransferred);

    /// @dev Emitted when a subscriber withdraws their rewards
    event RewardWithdraw(address indexed account, uint256 tokensTransferred);

    /// @dev Emitted when a subscriber slashed the rewards of another subscriber
    event RewardPointsSlashed(address indexed account, address indexed slasher, uint256 rewardPointsSlashed);

    /// @dev Emitted when tokens are allocated to the reward pool
    event RewardsAllocated(uint256 tokens);

    /// @dev Emitted when time is purchased (new nft or renewed)
    event Purchase(
        address indexed account,
        uint256 indexed tokenId,
        uint256 tokensTransferred,
        uint256 timePurchased,
        uint256 rewardPoints,
        uint256 expiresAt
    );

    /// @dev Emitted when a subscriber is granted time by the creator
    event Grant(address indexed account, uint256 indexed tokenId, uint256 secondsGranted, uint256 expiresAt);

    /// @dev Emitted when a subscriber is revoked time by the creator
    event GrantRevoke(address indexed account, uint256 indexed tokenId, uint256 secondsRevoked, uint256 expiresAt);

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

    /// @dev Emitted when a new referral code is created
    event ReferralCreated(uint256 id, uint16 bips);

    /// @dev Emitted when a referral code is deleted
    event ReferralDestroyed(uint256 id);

    /// @dev Emitted when the supply cap is updated
    event GlobalSupplyCapChange(uint256 supplyCap);

    /// @dev Emitted when the transfer recipient is updated
    event TransferRecipientChange(address indexed recipient);

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
