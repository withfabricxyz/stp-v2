// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/MulticallUpgradeable.sol";

import {InitParams, Tier, FeeParams, RewardParams, Tier, Pool, Subscription} from "./types/Index.sol";
import {PoolLib} from "./libraries/PoolLib.sol";
import {SubscriptionLib} from "./libraries/SubscriptionLib.sol";
import {TierLib} from "./libraries/TierLib.sol";
import {ISubscriptionTokenV2} from "./interfaces/ISubscriptionTokenV2.sol";
import {RewardLib} from "./libraries/RewardLib.sol";

/**
 * @title Subscription Token Protocol Version 2
 * @author Fabric Inc.
 * @notice An NFT contract which allows users to mint time and access token gated content while time remains.
 * @dev The balanceOf function returns the number of seconds remaining in the subscription. Token gated systems leverage
 *      the balanceOf function to determine if a user has the token, and if no time remains, the balance is 0. NFT holders
 *      can mint additional time. The creator/owner of the contract can withdraw the funds at any point. There are
 *      additional functionalities for granting time, refunding accounts, fees, rewards, etc. This contract is designed to be used with
 *      Clones, but is not designed to be upgradeable. Added functionality will come with new versions.
 */
contract SubscriptionTokenV2 is
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    MulticallUpgradeable,
    ISubscriptionTokenV2
{
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using PoolLib for Pool;
    using TierLib for Tier;
    using SubscriptionLib for Subscription;
    using RewardLib for RewardParams;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev Maximum protocol fee basis points (12.5%)
    uint16 private constant _MAX_FEE_BIPS = 1250;

    /// @dev Maximum basis points (100%)
    uint16 private constant _MAX_BIPS = 10000;

    /// @dev The metadata URI for the contract
    string private _contractURI;

    /// @dev The metadata URI for the tokens. Note: if it ends with /, then we append the tokenId
    string private _tokenURI;

    Pool private _creatorPool;
    Pool private _rewardPool;
    Pool private _rewardPointsPool;
    Pool private _feePool;

    /// @dev The token counter for mint id generation and enforcing supply caps
    uint256 private _tokenCounter;

    /// @dev The top level supply cap for all tiers (this include inactive subscriptions)
    uint64 private _globalSupplyCap;

    FeeParams private _feeParams;

    /// @dev The reward pool size (used to calculate reward withdraws accurately)
    uint256 private _totalRewardPoints;

    /// @dev The reward pool tokens slashed (used to calculate reward withdraws accurately)
    uint256 private _rewardPoolSlashed;

    RewardParams private _rewardParams;

    /// @dev The address of the account which can receive transfers via sponsored calls
    address private _transferRecipient;

    /// @dev The subscription state for each account
    mapping(address => Subscription) private _subscriptions;

    /// @dev The collection of referral codes for referral rewards
    mapping(uint256 => uint16) private _referralCodes;

    /// @dev The number of tiers created
    uint16 private _tierCount;

    /// @dev The available tiers (default tier has id = 1)
    mapping(uint16 => Tier) private _tiers;

    /// @dev The supply cap for each tier
    mapping(uint16 => uint32) private _tierSubCounts;

    ////////////////////////////////////

    modifier onlyManagement() {
        address account = _msgSender();
        if (!hasRole(DEFAULT_ADMIN_ROLE, account) && !hasRole(MANAGER_ROLE, account)) {
            revert AccessControlUnauthorizedAccount(account, MANAGER_ROLE);
        }
        _;
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    /// @dev Disable initializers on the logic contract
    constructor() {
        _disableInitializers();
    }

    /// @dev Fallback function to mint time for native token contracts
    receive() external payable {
        mintFor(msg.sender, msg.value);
    }

    function _initializeFees(FeeParams memory fees) private {
        if (fees.bips > _MAX_FEE_BIPS) {
            revert InvalidBps();
        }
        if (fees.collector != address(0)) {
            if (fees.bips == 0) {
                revert InvalidBps();
            }
        }
        _feeParams = fees;
    }

    function _initializeTier(Tier memory params) private {
        _tierCount += 1;
        if (params.id != _tierCount) {
            revert TierLib.TierInvalidId();
        }
        _tiers[params.id] = params.validate();
        emit TierCreated(_tierCount);
    }

    function initialize(InitParams memory params, Tier memory tier, RewardParams memory rewards, FeeParams memory fees)
        public
        initializer
    {
        if (params.owner == address(0)) {
            revert InvalidOwner();
        }

        if (bytes(params.name).length == 0) {
            revert InvalidName();
        }

        if (bytes(params.symbol).length == 0) {
            revert InvalidSymbol();
        }

        if (bytes(params.contractUri).length == 0) {
            revert InvalidContractUri();
        }

        if (bytes(params.tokenUri).length == 0) {
            revert InvalidTokenUri();
        }

        _creatorPool = Pool(0, 0, params.erc20TokenAddr);
        _rewardPool = Pool(0, 0, params.erc20TokenAddr);
        _feePool = Pool(0, 0, params.erc20TokenAddr);
        _contractURI = params.contractUri;
        _tokenURI = params.tokenUri;
        _globalSupplyCap = params.globalSupplyCap;
        _rewardParams = rewards.validate();
        _initializeFees(fees);
        _initializeTier(tier);

        __ERC721_init(params.name, params.symbol);
        __AccessControlDefaultAdminRules_init(0, params.owner);
        __ReentrancyGuard_init();
    }

    /////////////////////////
    // Subscriber Calls
    /////////////////////////

    /**
     * @notice Mint or renew a subscription for sender
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mint(uint256 numTokens) external payable {
        mintFor(msg.sender, numTokens);
    }

    /**
     * @notice Mint or renew a subscription for sender, with referral rewards for a referrer
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     * @param referralCode the referral code to use
     * @param referrer the referrer address and reward recipient
     */
    function mintWithReferral(uint256 numTokens, uint256 referralCode, address referrer) external payable {
        mintWithReferralFor(msg.sender, numTokens, referralCode, referrer);
    }

    /**
     * @notice Withdraw available rewards. This is only possible if the subscription is active.
     */
    function withdrawRewards() external {
        transferRewardsFor(msg.sender);
    }

    /**
     * @notice Slash the reward points for an expired subscription after a grace period which is 50% of the purchased time
     *         Any slashable points are burned, increasing the value of remaining points.
     * @param account the account of the subscription to slash
     */
    function slashRewards(address account) external {
        Subscription memory slasher = _subscriptions[msg.sender];
        slasher.checkActive();

        Subscription storage sub = _subscriptions[account];

        // Deflate the reward points pool and account for prior reward withdrawals
        _totalRewardPoints -= sub.rewardPoints;
        _rewardPoolSlashed += sub.rewardsWithdrawn;

        // If all points are slashed, move left-over funds to creator
        if (_totalRewardPoints == 0) {
            _rewardPool.liquidateTo(_creatorPool);
        }

        emit RewardPointsSlashed(account, msg.sender, sub.rewardPoints);
        RewardLib.slash(_rewardParams, sub);
    }

    /////////////////////////
    // Creator Calls
    /////////////////////////

    /**
     * @notice Withdraw available funds as the owner
     */
    function withdraw() external {
        withdrawTo(msg.sender);
    }

    /**
     * @notice Withdraw available funds and transfer fees as the owner
     */
    function withdrawAndTransferFees() external onlyAdmin {
        _transferAllBalances(msg.sender);
    }

    /**
     * @notice Withdraw available funds as the owner to a specific account
     * @param account the account to transfer funds to
     */
    function withdrawTo(address account) public onlyAdmin {
        _transferToCreator(account, creatorBalance());
    }

    /**
     * @notice Refund an account, clearing the subscription and revoking any grants, and paying out a set amount
     * @dev This refunds using the creator balance. If there is not enough balance, it will fail.
     * @param account the account to refund
     * @param numTokens the amount of tokens to refund
     */
    function refund(address account, uint256 numTokens) external onlyAdmin {
        Subscription storage sub = _getSub(account);
        (uint256 refundedTokens, uint256 refundedSeconds) = sub.refund(numTokens);
        emit Refund(account, sub.tokenId, refundedTokens, refundedSeconds);
        _creatorPool.transferOut(account, refundedTokens);
    }

    /**
     * @notice Top up the creator balance. Useful for refunds.
     * @param numTokens the amount of tokens to transfer
     */
    function topUp(uint256 numTokens) external payable onlyManagement {
        emit TopUp(numTokens);
        _creatorPool.transferIn(msg.sender, numTokens);
    }

    /**
     * @notice Update the contract metadata
     * @param contractUri the collection metadata URI
     * @param tokenUri the token metadata URI
     */
    function updateMetadata(string memory contractUri, string memory tokenUri) external onlyManagement {
        if (bytes(contractUri).length == 0) {
            revert InvalidContractUri();
        }
        if (bytes(tokenUri).length == 0) {
            revert InvalidTokenUri();
        }
        _contractURI = contractUri;
        _tokenURI = tokenUri;
    }

    /**
     * @notice Grant time to a given account
     * @param account the account to grant time to
     * @param numSeconds the number of seconds to grant
     * @param tierId the tier id to grant time to (0 to match current tier, or default for new)
     */
    function grantTime(address account, uint256 numSeconds, uint16 tierId) external onlyManagement {
        Subscription storage sub = _fetchSubscription(account, tierId);
        sub.grantTime(numSeconds);
        // Mint the NFT if it does not exist before grant event for indexers
        // TODO: Can this be in the fetch?
        emit Grant(account, sub.tokenId, numSeconds, sub.expiresAt());
        _maybeMint(account, sub.tokenId);
    }

    /**
     * @notice Revoke time from a given account
     * @param account the account to revoke time from
     */
    function revokeTime(address account) external onlyManagement {
        Subscription storage sub = _getSub(account);
        uint256 time = sub.revokeTime();
        emit GrantRevoke(account, sub.tokenId, time, sub.expiresAt());
    }

    /**
     * @notice Set a transfer recipient for automated/sponsored transfers
     * @param recipient the recipient address
     */
    function setTransferRecipient(address recipient) external onlyAdmin {
        _transferRecipient = recipient;
        emit TransferRecipientChange(recipient);
    }

    /**
     * @notice Set the global supply cap for all tiers
     * @param supplyCap the new supply cap
     */
    function setGlobalSupplyCap(uint64 supplyCap) external onlyManagement {
        if (_tokenCounter > supplyCap) {
            revert GlobalSupplyLimitExceeded();
        }
        _globalSupplyCap = supplyCap;
        emit GlobalSupplyCapChange(supplyCap);
    }

    /////////////////////////
    // Tier Management
    /////////////////////////

    /**
     * @notice Create a new tier
     * @param params the tier parameters
     */
    function createTier(Tier memory params) external onlyAdmin {
        _initializeTier(params);
    }

    /**
     * @notice Update the supply cap for a given tier
     * @param tierId the id of the tier to update
     * @param supplyCap the new supply cap
     */
    function setTierSupplyCap(uint16 tierId, uint32 supplyCap) public onlyAdmin {
        Tier storage tier = _getTier(tierId);
        if (supplyCap != 0 && supplyCap < _tierSubCounts[tierId]) {
            revert TierLib.TierInvalidSupplyCap();
        }
        tier.maxSupply = supplyCap;
        emit TierSupplyCapChange(tierId, supplyCap);
    }

    /**
     * @notice Update the price per period for a given tier
     * @param tierId the id of the tier to update
     * @param pricePerPeriod the new price per period
     */
    function setTierPrice(uint16 tierId, uint256 pricePerPeriod) external onlyAdmin {
        _getTier(tierId).pricePerPeriod = pricePerPeriod;
        emit TierPriceChange(tierId, pricePerPeriod);
    }

    /**
     * @notice Pause a tier, preventing new subscriptions and renewals
     * @param tierId the id of the tier to pause
     */
    function pauseTier(uint16 tierId) external onlyManagement {
        _getTier(tierId).paused = true;
        emit TierPaused(tierId);
    }

    /**
     * @notice Unpause a tier, resuming new subscriptions and renewals
     * @param tierId the id of the tier to unpause
     */
    function unpauseTier(uint16 tierId) external onlyManagement {
        _getTier(tierId).paused = false;
        emit TierUnpaused(tierId);
    }

    /////////////////////////
    // Sponsored Calls
    /////////////////////////

    /**
     * @notice Mint or renew a subscription for a specific account. Intended for automated renewals.
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mintFor(address account, uint256 numTokens) public payable {
        _mintOrRenew(account, numTokens, 0, 0, address(0));
    }

    /**
     * @notice Mint or renew a subscription for a specific account, with referral details
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     * @param referralCode the referral code to use for rewards
     * @param referrer the referrer address and reward recipient
     */
    function mintWithReferralFor(address account, uint256 numTokens, uint256 referralCode, address referrer)
        public
        payable
    {
        if (referrer == address(0)) {
            revert InvalidAccount();
        }
        _mintOrRenew(account, numTokens, 0, referralCode, referrer);
    }

    /// @dev Associate the subscription with the tier, adjusting the cap, etc
    function _joinTier(Subscription storage sub, Tier memory tier, address account, uint256 numTokens)
        internal
        returns (uint256)
    {
        // TODO: What do we do for existing time?
        uint32 subs = _tierSubCounts[tier.id];

        tier.checkJoin(subs, account, numTokens);

        sub.tierId = tier.id;
        _tierSubCounts[tier.id] = subs + 1;
        // TODO: emit switch tier!

        // Return the remaining balance
        return numTokens - tier.initialMintPrice;
    }

    /**
     * @dev Create a new subscription and NFT for the given account
     */
    function _mint(Subscription storage sub, address account) internal {
        if (_globalSupplyCap != 0 && _tokenCounter >= _globalSupplyCap) {
            revert GlobalSupplyLimitExceeded();
        }

        _tokenCounter += 1;
        sub.tokenId = _tokenCounter;
        _maybeMint(account, sub.tokenId);
    }

    function _mintOrRenew(address account, uint256 numTokens, uint16 tierId, uint256 referralCode, address referrer)
        internal
    {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        uint256 tokensIn = _creatorPool.transferIn(msg.sender, numTokens);
        uint256 tokensForTime = tokensIn;

        Subscription storage sub = _subscriptions[account];

        // If the subscription does not exist, mint the token
        if (sub.tokenId == 0) {
            _mint(sub, account);
        }

        // Switch tiers if necessary (checking join logic and pricing)
        if (sub.tierId == 0 || (tierId != 0 && sub.tierId != tierId)) {
            tokensForTime = _joinTier(sub, _getTier(tierId == 0 ? 1 : tierId), account, tokensForTime);
        }

        // Renew the subscription (add time)

        Tier memory tier = _getTier(sub.tierId);
        tier.checkRenewal(sub, tokensForTime);

        // (uint256 ) sub.update(tier, tokensIn, tokensForTime, rewardMultiplier())

        if (block.timestamp > sub.purchaseOffset + sub.secondsPurchased) {
            sub.purchaseOffset = block.timestamp - sub.secondsPurchased;
        }

        uint256 rp = tokensIn * rewardMultiplier() * tier.rewardMultiplier;
        uint256 tv = tier.tokensToSeconds(tokensForTime);
        sub.totalPurchased += tokensForTime;
        sub.secondsPurchased += tv;
        sub.rewardPoints += rp;
        // _subscriptions[account] = sub; ???
        // set the total tokens paid in the subscription
        _totalRewardPoints += rp;

        // TODO sub.purchase(tier, tokensTransferred);
        uint256 remaining = tokensIn;
        if (referrer != address(0)) {
            uint256 payout = _referralAmount(remaining, referralCode);
            if (payout > 0) {
                _creatorPool.transferOut(referrer, payout);
                emit ReferralPayout(sub.tokenId, referrer, referralCode, payout);
                remaining -= payout;
            }
        }

        _allocateFeesAndRewards(remaining);

        emit Purchase(account, sub.tokenId, numTokens, tv, rp, sub.expiresAt());
    }

    /**
     * @notice Transfer any available fees to the fee collector
     */
    function transferFees() external {
        _transferFees();
    }

    /**
     * @notice Transfer all balances to the transfer recipient and fee collector (if applicable)
     * @dev This is a way for EOAs to pay gas fees on behalf of the creator (automation, etc)
     */
    function transferAllBalances() external {
        _transferAllBalances(_transferRecipient);
    }

    // @inheritdoc ISubscriptionTokenV2
    function distributeRewards(uint256 numTokens) external payable override {
        if (_totalRewardPoints == 0) {
            revert RewardLib.RewardsDisabled();
        }
        uint256 finalAmount = _rewardPool.transferIn(msg.sender, numTokens);
        emit RewardsAllocated(finalAmount);
    }

    // @inheritdoc ISubscriptionTokenV2
    function transferRewardsFor(address account) public override {
        Subscription storage sub = _getSub(account);
        sub.checkActive();
        uint256 amount = _rewardBalance(sub);
        sub.rewardsWithdrawn += amount;
        emit RewardWithdraw(account, amount);
        _rewardPool.transferOut(account, amount);
    }

    // @inheritdoc ISubscriptionTokenV2
    function deactivateSubscription(address account) external {
        Subscription storage sub = _getSub(account);
        _tierSubCounts[sub.tierId] -= 1;
        sub.deactivate();
        // emit Deactivatation(account, sub.tokenId);
    }

    /////////////////////////
    // Fee Management
    /////////////////////////

    /**
     * @notice Fetch the current fee schedule
     * @return feeCollector the feeCollector address
     * @return feeBps the fee basis points
     */
    function feeSchedule() external view returns (address feeCollector, uint16 feeBps) {
        return (_feeParams.collector, _feeParams.bips);
    }

    /**
     * @notice Fetch the accumulated fee balance
     * @return balance the accumulated fees which have not yet been transferred
     */
    function feeBalance() external view returns (uint256 balance) {
        return _feePool.balance();
    }

    /**
     * @notice Update the fee collector address. Can be set to 0x0 to disable fees permanently.
     * @param newCollector the new fee collector address
     */
    function updateFeeRecipient(address newCollector) external {
        if (msg.sender != _feeParams.collector) {
            revert Unauthorized();
        }

        // Give tokens back to creator and set fee rate to 0
        if (newCollector == address(0)) {
            _feePool.liquidateTo(_creatorPool);
            _feeParams.bips = 0;
        }
        _feeParams.collector = newCollector;
        emit FeeCollectorChange(newCollector);
    }

    /////////////////////////
    // Referral Rewards
    /////////////////////////

    /**
     * @notice Create a referral code for giving rewards to referrers on mint
     * @param code the unique integer code for the referral
     * @param bps the reward basis points
     */
    function createReferralCode(uint256 code, uint16 bps) external onlyAdmin {
        if (bps == 0 || bps > _MAX_BIPS) {
            revert InvalidBps();
        }

        if (_referralCodes[code] != 0) {
            revert ReferralExists(code);
        }

        _referralCodes[code] = bps;
        emit ReferralCreated(code, bps);
    }

    /**
     * @notice Delete a referral code
     * @param code the unique integer code for the referral
     */
    function deleteReferralCode(uint256 code) external onlyAdmin {
        delete _referralCodes[code];
        emit ReferralDestroyed(code);
    }

    /**
     * @notice Fetch the reward basis points for a given referral code
     * @param code the unique integer code for the referral
     * @return bps the reward basis points
     */
    function referralCodeBps(uint256 code) external view returns (uint16 bps) {
        return _referralCodes[code];
    }

    ////////////////////////
    // Core Internal Logic
    ////////////////////////

    function _getTier(uint16 tierId) internal view returns (Tier storage) {
        Tier storage tier = _tiers[tierId];
        if (tier.id == 0) {
            revert TierLib.TierNotFound(tierId);
        }
        return tier;
    }

    function _getSub(address account) internal view returns (Subscription storage) {
        Subscription storage sub = _subscriptions[account];
        if (sub.tokenId == 0) {
            revert SubscriptionLib.SubscriptionNotFound(account);
        }
        return sub;
    }

    /// @dev Get or build a new subscription (for writing)
    function _fetchSubscription(address account, uint16 tierId) internal returns (Subscription storage) {
        Subscription storage sub = _subscriptions[account];
        if (sub.tokenId == 0) {
            // checkTier(tierId);
            _tokenCounter += 1;
            sub.tokenId = _tokenCounter;
            sub.tierId = tierId;
            // _safeMint(account, sub.tokenId);
        }
        return sub;
    }

    /// @dev Mint the NFT if it does not exist. Used after grant/purchase state changes (check effects)
    function _maybeMint(address account, uint256 tokenId) private {
        if (_ownerOf(tokenId) == address(0)) {
            _safeMint(account, tokenId);
        }
    }

    /// @dev If fees or rewards are present, allocate a portion of the amount to the relevant pools
    function _allocateFeesAndRewards(uint256 amount) private {
        _allocateRewards(_allocateFees(amount));
    }

    /// @dev Allocate tokens to the fee collector
    function _allocateFees(uint256 amount) internal returns (uint256) {
        if (_feeParams.bips == 0) {
            return amount;
        }
        uint256 fee = (amount * _feeParams.bips) / _MAX_BIPS;
        _creatorPool.transferTo(_feePool, fee);
        emit FeeAllocated(fee);
        return amount - fee;
    }

    /// @dev Allocate tokens to the reward pool
    function _allocateRewards(uint256 amount) internal returns (uint256) {
        if (_rewardParams.bips == 0 || _totalRewardPoints == 0) {
            return amount;
        }
        uint256 rewards = (amount * _rewardParams.bips) / _MAX_BIPS;
        _creatorPool.transferTo(_rewardPool, rewards);
        emit RewardsAllocated(rewards);
        return amount - rewards;
    }

    /// @dev Transfer tokens to the creator, after allocating protocol fees and rewards
    function _transferToCreator(address to, uint256 amount) internal {
        emit Withdraw(to, amount);
        _creatorPool.transferOut(to, amount);
    }

    /// @dev Transfer fees to the fee collector
    function _transferFees() internal {
        uint256 balance = _feePool.balance();
        _feePool.transferOut(_feeParams.collector, balance);
        emit FeeTransfer(msg.sender, _feeParams.collector, balance);
    }

    /// @dev Transfer all remaining balances to the creator and fee collector (if applicable)
    function _transferAllBalances(address balanceRecipient) internal {
        uint256 balance = creatorBalance();
        if (balance > 0) {
            _transferToCreator(balanceRecipient, balance);
        }

        // Transfer protocol fees
        if (_feePool.balance() > 0) {
            _transferFees();
        }
    }

    /// @dev Compute the reward amount for a given token amount and referral code
    function _referralAmount(uint256 tokenAmount, uint256 referralCode) internal view returns (uint256) {
        uint16 referralBps = _referralCodes[referralCode];
        if (referralBps == 0) {
            return 0;
        }
        return (tokenAmount * referralBps) / _MAX_BIPS;
    }

    /// @dev The reward balance for a given subscription
    function _rewardBalance(Subscription memory sub) internal view returns (uint256) {
        uint256 userShare = (_rewardPool.total() - _rewardPoolSlashed) * sub.rewardPoints / _totalRewardPoints;
        if (userShare <= sub.rewardsWithdrawn) {
            return 0;
        }
        return userShare - sub.rewardsWithdrawn;
    }

    ////////////////////////
    // Informational
    ////////////////////////

    function estimatedRefund(address account) public view returns (uint256) {
        return _getSub(account).estimatedRefund();
    }

    /**
     * @notice The current reward multiplier used to calculate reward points on mint. This is halved every _minPurchaseSeconds and goes to 0 after N halvings.
     * @return multiplier the current value
     */
    function rewardMultiplier() public view returns (uint256 multiplier) {
        return _rewardParams.currentMultiplier();
    }

    /**
     * @notice The creators withdrawable balance
     * @return balance the number of tokens available for withdraw
     */
    function creatorBalance() public view returns (uint256 balance) {
        return _creatorPool.balance();
    }

    /**
     * @notice The sum of all deposited tokens over time. Fees and refunds are not accounted for.
     * @return total the total number of tokens deposited
     */
    function totalCreatorEarnings() public view returns (uint256 total) {
        return _creatorPool.total();
    }

    /**
     * @notice Relevant subscription information for a given account
     * @return tokenId the tokenId for the account
     * @return refundableAmount the number of seconds which can be refunded
     * @return rewardPoints the number of reward points earned
     * @return expiresAt the timestamp when the subscription expires
     */
    function subscriptionOf(address account)
        external
        view
        returns (uint256 tokenId, uint256 refundableAmount, uint256 rewardPoints, uint256 expiresAt)
    {
        Subscription memory sub = _subscriptions[account];
        return (sub.tokenId, sub.secondsPurchased, sub.rewardPoints, sub.expiresAt());
    }

    function subscriptionDetail(address account) external view returns (Subscription memory subscription) {
        return _subscriptions[account];
    }

    /**
     * @notice The percentage (as basis points) of creator earnings which are rewarded to subscribers
     * @return bps reward basis points
     */
    function bips() external view returns (uint16 bps) {
        return _rewardParams.bips;
    }

    /**
     * @notice The number of reward points allocated to all subscribers (used to calculate rewards)
     * @return numPoints total number of reward points
     */
    function totalRewardPoints() external view returns (uint256 numPoints) {
        return _totalRewardPoints; //_rewardPool.total();
    }

    /**
     * @notice The balance of the reward pool (for reward withdraws)
     * @return numTokens number of tokens in the reward pool
     */
    function rewardPoolBalance() external view returns (uint256 numTokens) {
        return _rewardPool.balance();
    }

    /**
     * @notice The number of tokens available to withdraw from the reward pool, for a given account
     * @param account the account to check
     * @return numTokens number of tokens available to withdraw
     */
    function rewardBalanceOf(address account) external view returns (uint256 numTokens) {
        Subscription memory sub = _subscriptions[account];
        return _rewardBalance(sub);
    }

    /**
     * @notice The ERC-20 address used for purchases, or 0x0 for native
     * @return erc20 address or 0x0 for native
     */
    function erc20Address() public view returns (address erc20) {
        return _creatorPool.tokenAddress;
    }

    /**
     * @notice The refundable time balance for a given account
     * @param account the account to check
     * @return numSeconds the number of seconds which can be refunded
     */
    function refundableBalanceOf(address account) public view returns (uint256 numSeconds) {
        return _subscriptions[account].purchasedTimeRemaining();
    }

    /**
     * @notice The contract metadata URI for accessing collection metadata
     * @return uri the collection URI
     */
    function contractURI() public view returns (string memory uri) {
        return _contractURI;
    }

    /**
     * @notice The base token URI for accessing token metadata
     * @return uri the base token URI
     */
    function baseTokenURI() public view returns (string memory uri) {
        return _tokenURI;
    }

    /**
     * @notice The minimum number of seconds required for a purchase
     * @return numSeconds minimum
     */
    function minPurchaseSeconds() external view returns (uint256 numSeconds) {
        return _getTier(1).periodDurationSeconds;
    }

    /// @inheritdoc ISubscriptionTokenV2
    function tierSupply(uint16 tierId) external view override returns (uint32 currentSupply, uint32 maxSupply) {
        Tier memory tier = _getTier(tierId);
        return (_tierSubCounts[tier.id], tier.maxSupply);
    }

    /// @inheritdoc ISubscriptionTokenV2
    function tierDetails(uint16 tierId) external view override returns (Tier memory tier) {
        return _getTier(tierId);
    }

    /// @inheritdoc ISubscriptionTokenV2
    function tierCount() external view override returns (uint16 count) {
        return _tierCount;
    }

    /**
     * @notice Fetch the current transfer recipient address
     * @return recipient the address or 0x0 address for none
     */
    function transferRecipient() external view returns (address recipient) {
        return _transferRecipient;
    }

    /**
     * @notice Fetch the metadata URI for a given token
     * @dev If _tokenURI ends with a / then the tokenId is appended
     * @param tokenId the tokenId to fetch the metadata URI for
     * @return uri the URI for the token
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        _requireOwned(tokenId);

        bytes memory str = bytes(_tokenURI);
        uint256 len = str.length;
        if (str[len - 1] == "/") {
            return string(abi.encodePacked(_tokenURI, tokenId.toString()));
        }

        return _tokenURI;
    }

    /// @inheritdoc ISubscriptionTokenV2
    function stpVersion() external pure returns (uint8 version) {
        return 2;
    }

    /// @inheritdoc ISubscriptionTokenV2
    function tierBalanceOf(uint16 tierId, address account) external view returns (uint256 numSeconds) {
        Subscription memory sub = _subscriptions[account];
        if (sub.tierId != tierId) {
            return 0;
        }
        return sub.remainingSeconds();
    }

    //////////////////////
    // Overrides
    //////////////////////

    /**
     * @notice Override the default balanceOf behavior to account for time remaining
     * @param account the account to fetch the balance of
     * @return numSeconds the number of seconds remaining in the subscription
     */
    function balanceOf(address account) public view override returns (uint256 numSeconds) {
        return _subscriptions[account].remainingSeconds();
    }

    /**
     * @notice Renounce ownership of the contract, transferring all remaining funds to the creator and fee collector
     *         and pausing the contract to prevent further inflows.
     */
    function renounceOwnership() public onlyAdmin {
        _transferAllBalances(msg.sender);
        // TODO: Need to understand this....
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // _renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // _transferOwnership(address(0));
        // pause all tiers?
    }

    /// @dev Transfers may occur if the destination does not have a subscription and the tier allows it
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from == address(0)) {
            return from;
        }

        Subscription memory sub = _subscriptions[from];
        if (sub.tierId != 0) {
            Tier memory tier = _tiers[sub.tierId];
            if (!tier.transferrable) {
                revert TierLib.TierTransferDisabled();
            }
        }

        if (_subscriptions[to].tokenId != 0) {
            revert InvalidTransfer();
        }

        if (to != address(0)) {
            _subscriptions[to] = _subscriptions[from];
        }
        delete _subscriptions[from];

        return from;
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlDefaultAdminRulesUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    //////////////////////
    // Recovery Functions
    //////////////////////

    /**
     * @notice Recover ERC20 tokens which were accidentally sent to the contract
     * @param tokenAddress the address of the token to recover
     * @param recipientAddress the address to send the tokens to
     * @param tokenAmount the amount of tokens to send
     */
    function recoverERC20(address tokenAddress, address recipientAddress, uint256 tokenAmount) external onlyAdmin {
        if (tokenAddress == erc20Address()) {
            revert InvalidRecovery();
        }
        IERC20(tokenAddress).safeTransfer(recipientAddress, tokenAmount);
    }

    /**
     * @notice Recover native tokens which bypassed receive. Only callable for erc20 denominated contracts.
     * @param recipient the address to send the tokens to
     */
    function recoverNativeTokens(address recipient) external onlyAdmin {
        if (erc20Address() == address(0)) {
            revert InvalidRecovery();
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert InvalidRecovery();
        }

        (bool sent,) = payable(recipient).call{value: balance}("");
        if (!sent) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Reconcile the token balance for native token contracts. This is used to reconcile the balance
     */
    function reconcileBalance() external onlyAdmin {
        // TODO: More tests
        _creatorPool.reconcileBalance(_creatorPool.balance() + _feePool.balance() + _rewardPool.balance());
    }
}
