// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ISubscriptionTokenV2 {
    //////////////////
    // EVENTS
    //////////////////

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

    /// @dev Emitted when the creator refunds a subscribers remaining time
    event Refund(address indexed account, uint256 indexed tokenId, uint256 tokensTransferred, uint256 timeReclaimed);

    /// @dev Emitted when the creator tops up the contract balance on refund
    event RefundTopUp(uint256 tokensIn);

    /// @dev Emitted when the fees are transferred to the collector
    event FeeTransfer(address indexed from, address indexed to, uint256 tokensTransferred);

    /// @dev Emitted when the fee collector is updated
    event FeeCollectorChange(address indexed from, address indexed to);

    /// @dev Emitted when tokens are allocated to the fee pool
    event FeeAllocated(uint256 tokens);

    /// @dev Emitted when a referral fee is paid out
    event ReferralPayout(
        uint256 indexed tokenId, address indexed referrer, uint256 indexed referralId, uint256 rewardAmount
    );

    /// @dev Emitted when a new referral code is created
    event ReferralCreated(uint256 id, uint16 bips);

    /// @dev Emitted when a referral code is deleted
    event ReferralDestroyed(uint256 id);

    /// @dev Emitted when the supply cap is updated
    event SupplyCapChange(uint256 supplyCap);

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
     * @notice Mint or renew a subscription for sender, with referral rewards for a referrer
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     * @param referralCode the referral code to use
     * @param referrer the referrer address and reward recipient
     */
    function mintWithReferral(uint256 numTokens, uint256 referralCode, address referrer) external payable;

    /**
     * @notice Mint or renew a subscription for a specific account. Intended for automated renewals.
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mintFor(address account, uint256 numTokens) external payable;

    /**
     * @notice Mint or renew a subscription for a specific account, with referral details
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     * @param referralCode the referral code to use for rewards
     * @param referrer the referrer address and reward recipient
     */
    function mintWithReferralFor(address account, uint256 numTokens, uint256 referralCode, address referrer)
        external
        payable;

    //~~~~~~~~~~~ V2 ~~~~~~~~~~~~//

    /**
     * @notice Fetch the current version of the contract
     * @return version the current version
     */
    function stpVersion() external pure returns (uint8 version);

    function grantTime(address account, uint256 numSeconds, uint16 tierId) external;

    function revokeTime(address account) external;

    // function mintPrice(address account, uint8 tierId, uint32 numPeriods) external view returns (uint256);

    /**
     * @notice Mark subscriptions as inactive and move them to the inactive tier
     * @dev This checks each subscription and moves it to the inactive tier (tierId = 0) if it has expired
     * @param subscribers the list of subscriber addresses to mark as inactive
     */
    // function markInactive(address[] calldata subscribers) external;

    /**
     * @notice Get the balance of an account in a specific tier
     * @param tierId the tier id filter
     * @param account the account to check the balance of
     * @return the balance of the account in the specified tier
     */
    function tierBalanceOf(uint16 tierId, address account) external view returns (uint256);

    //////////////////
    // Rewards
    //////////////////

    /**
     * @notice Distribute rewards to subscribers
     * @param numTokens the amount of ERC20 or native tokens to add to the reward pool
     */
    function distributeRewards(uint256 numTokens) external payable;
}
