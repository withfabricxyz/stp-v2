// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {AccessControlled} from "./abstracts/AccessControlled.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {ERC721} from "@solady/tokens/ERC721.sol";
import {InitParams, Tier, FeeParams, RewardParams, Tier, Subscription} from "./types/Index.sol";
import {SubscriptionLib} from "./libraries/SubscriptionLib.sol";
import {TierLib} from "./libraries/TierLib.sol";
import {ISubscriptionTokenV2} from "./interfaces/ISubscriptionTokenV2.sol";
// import {ERC721} from "./abstracts/ERC721.sol";
// import {Proxied} from "./abstracts/Proxied.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";
import {IRewardPool} from "./interfaces/IRewardPool.sol";

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
contract SubscriptionTokenV2 is ERC721, AccessControlled, Multicallable, Initializable, ISubscriptionTokenV2 {
    using LibString for uint256;
    using TierLib for Tier;
    using SubscriptionLib for Subscription;
    using CurrencyLib for Currency;

    uint16 private constant ROLE_MANAGER = 1;
    uint16 private constant ROLE_AGENT = 2;

    /// @dev Maximum protocol fee basis points (12.5%)
    uint16 private constant _MAX_FEE_BIPS = 1250;

    /// @dev Maximum basis points (100%)
    uint16 private constant _MAX_BIPS = 10000;

    /// @dev The metadata URI for the contract (tokenUri is derived from this)
    string public contractURI;

    string private _name;

    string private _symbol;

    /// @dev The token counter for mint id generation and enforcing supply caps
    uint256 private _tokenCounter;

    /// @dev The top level supply cap for all tiers (this include inactive subscriptions)
    uint64 private _globalSupplyCap;

    FeeParams public feeParams;

    /// @dev The reward pool parameters (pollAddress (0 = disabled), and the bips)
    RewardParams private _rewardParams;

    Currency private _currency;

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
        feeParams = fees;
    }

    function _initializeTier(Tier memory params) private {
        _tierCount += 1;
        if (params.id != _tierCount) {
            revert TierLib.TierInvalidId();
        }
        params.validate();
        _tiers[params.id] = params;
        emit TierCreated(_tierCount);
    }

    function _initializeRewards(RewardParams memory params) private {
        if (params.bips > _MAX_BIPS) {
            revert InvalidBps();
        }
        _rewardParams = params;
    }

    function _initializeCore(InitParams memory params) private {
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

        _setOwner(params.owner);
        _name = params.name;
        _symbol = params.symbol;
        contractURI = params.contractUri;
        _globalSupplyCap = params.globalSupplyCap;

        _currency = Currency.wrap(params.erc20TokenAddr);
    }

    function initialize(InitParams memory params, Tier memory tier, RewardParams memory rewards, FeeParams memory fees)
        public
        initializer
    {
        // TODO: If we inline all this, it will be smaller
        _initializeCore(params);
        _initializeFees(fees);
        _initializeTier(tier);
        _initializeRewards(rewards);
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

    /////////////////////////
    // Creator Calls
    /////////////////////////

    function transferFunds(address to, uint256 amount) external {
        if (to == address(0)) {
            revert InvalidAccount();
        }

        if (to != _transferRecipient) {
            _checkOwner();
        }

        emit Withdraw(to, amount);
        _currency.transfer(to, amount);
    }

    /**
     * @notice Refund an account, clearing the subscription and revoking any grants, and paying out a set amount
     * @dev This refunds using the creator balance. If there is not enough balance, it will fail.
     * @param account the account to refund
     * @param numTokens the amount of tokens to refund
     */
    function refund(address account, uint256 numTokens) external {
        _checkOwner();
        Subscription storage sub = _getSub(account);
        (uint256 refundedTokens, uint256 refundedSeconds) = sub.refund(numTokens);
        emit Refund(account, sub.tokenId, refundedTokens, refundedSeconds);
        _currency.transfer(account, refundedTokens);
    }

    /**
     * @notice Top up the creator balance. Useful for refunds.
     * @param numTokens the amount of tokens to transfer
     */
    function topUp(uint256 numTokens) external payable {
        _checkOwnerOrRoles(ROLE_MANAGER);
        emit TopUp(numTokens);
        _currency.capture(msg.sender, numTokens);
    }

    /**
     * @notice Update the contract metadata
     * @param uri the collection metadata URI
     */
    function updateMetadata(string memory uri) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        if (bytes(uri).length == 0) {
            revert InvalidContractUri();
        }
        contractURI = uri;
    }

    /**
     * @notice Grant time to a given account
     * @param account the account to grant time to
     * @param numSeconds the number of seconds to grant
     * @param tierId the tier id to grant time to (0 to match current tier, or default for new)
     */
    function grantTime(address account, uint48 numSeconds, uint16 tierId) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);

        Subscription storage sub = _subscriptions[account];
        // If the subscription does not exist, mint the token
        if (sub.tokenId == 0) {
            _mint(sub, account);
        }

        // TODO: Check join tier logic, etc
        sub.tierId = tierId;
        sub.grantTime(numSeconds);
        emit Grant(account, sub.tokenId, numSeconds, sub.expiresAt());
    }

    /**
     * @notice Revoke time from a given account
     * @param account the account to revoke time from
     */
    function revokeTime(address account) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);
        Subscription storage sub = _getSub(account);
        uint256 time = sub.revokeTime();
        emit GrantRevoke(account, sub.tokenId, time, sub.expiresAt());
    }

    /**
     * @notice Set a transfer recipient for automated/sponsored transfers
     * @param recipient the recipient address
     */
    function setTransferRecipient(address recipient) external {
        _checkOwner();
        _transferRecipient = recipient;
        emit TransferRecipientChange(recipient);
    }

    /**
     * @notice Set the global supply cap for all tiers
     * @param supplyCap the new supply cap
     */
    function setGlobalSupplyCap(uint64 supplyCap) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
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
    function createTier(Tier memory params) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        _initializeTier(params);
    }

    /**
     * @notice Update the supply cap for a given tier
     * @param tierId the id of the tier to update
     * @param supplyCap the new supply cap
     */
    function setTierSupplyCap(uint16 tierId, uint32 supplyCap) public {
        _checkOwnerOrRoles(ROLE_MANAGER);
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
    function setTierPrice(uint16 tierId, uint256 pricePerPeriod) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);
        _getTier(tierId).pricePerPeriod = pricePerPeriod;
        emit TierPriceChange(tierId, pricePerPeriod);
    }

    /**
     * @notice Pause a tier, preventing new subscriptions and renewals
     * @param tierId the id of the tier to pause
     */
    function pauseTier(uint16 tierId) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);
        _getTier(tierId).paused = true;
        emit TierPaused(tierId);
    }

    /**
     * @notice Unpause a tier, resuming new subscriptions and renewals
     * @param tierId the id of the tier to unpause
     */
    function unpauseTier(uint16 tierId) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);
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
        _safeMint(account, sub.tokenId);
    }

    function _mintOrRenew(address account, uint256 numTokens, uint16 tierId, uint256 referralCode, address referrer)
        internal
    {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        uint256 tokensIn = _currency.capture(msg.sender, numTokens);
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

        uint48 numSeconds = tier.tokensToSeconds(tokensForTime);
        sub.renew(tokensForTime, numSeconds);

        // TODO sub.purchase(tier, tokensTransferred);
        uint256 remaining = tokensIn;
        if (referrer != address(0)) {
            uint256 payout = _referralAmount(remaining, referralCode);
            if (payout > 0) {
                _currency.transfer(referrer, payout);
                emit ReferralPayout(sub.tokenId, referrer, referralCode, payout);
                remaining -= payout;
            }
        }

        remaining = _transferFees(remaining);
        remaining = _transferRewards(account, remaining, tier.rewardMultiplier);

        emit Purchase(account, sub.tokenId, numTokens, numSeconds, 0, sub.expiresAt());
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
     * @notice Update the fee collector address. Can be set to 0x0 to disable fees permanently.
     * @param newCollector the new fee collector address
     */
    function updateFeeRecipient(address newCollector) external {
        if (msg.sender != feeParams.collector) {
            revert Unauthorized();
        }

        // Give tokens back to creator and set fee rate to 0
        if (newCollector == address(0)) {
            feeParams.bips = 0;
        }
        feeParams.collector = newCollector;
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
    function createReferralCode(uint256 code, uint16 bps) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
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
    function deleteReferralCode(uint256 code) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
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

    function _getTier(uint16 tierId) private view returns (Tier storage) {
        Tier storage tier = _tiers[tierId];
        if (tier.id == 0) {
            revert TierLib.TierNotFound(tierId);
        }
        return tier;
    }

    function _getSub(address account) private view returns (Subscription storage) {
        Subscription storage sub = _subscriptions[account];
        if (sub.tokenId == 0) {
            revert SubscriptionLib.SubscriptionNotFound(account);
        }
        return sub;
    }

    /// @dev Allocate tokens to the fee collector
    function _transferFees(uint256 amount) private returns (uint256) {
        if (feeParams.bips == 0) {
            return amount;
        }
        uint256 fee = (amount * feeParams.bips) / _MAX_BIPS;
        if (fee == 0) {
            return amount;
        }

        _currency.transfer(feeParams.collector, fee);
        emit FeeTransfer(feeParams.collector, fee);
        return amount - fee;
    }

    function _transferRewards(address account, uint256 amount, uint8 multiplier) private returns (uint256) {
        if (_rewardParams.poolAddress == address(0)) {
            return amount;
        }

        uint256 rewards = (amount * _rewardParams.bips) / _MAX_BIPS;
        if (rewards == 0) {
            return amount;
        }

        if (_currency.isNative()) {
            // need to perform the call with value, or approve
            IRewardPool(_rewardParams.poolAddress).mint{value: rewards}(account, amount * multiplier, rewards);
        } else {
            // need to perform the call with value, or approve
            _currency.approve(_rewardParams.poolAddress, rewards);
            IRewardPool(_rewardParams.poolAddress).mint(account, amount * multiplier, rewards);
        }
        return amount - rewards;
    }

    /// @dev Compute the reward amount for a given token amount and referral code
    function _referralAmount(uint256 tokenAmount, uint256 referralCode) internal view returns (uint256) {
        uint16 referralBps = _referralCodes[referralCode];
        if (referralBps == 0) {
            return 0;
        }
        return (tokenAmount * referralBps) / _MAX_BIPS;
    }

    ////////////////////////
    // Informational
    ////////////////////////

    function estimatedRefund(address account) public view returns (uint256) {
        return _getSub(account).estimatedRefund();
    }

    /**
     * @notice The creators withdrawable balance
     * @return balance the number of tokens available for withdraw
     */
    function creatorBalance() public view returns (uint256 balance) {
        return _currency.balance();
    }

    function subscriptionOf(address account) external view returns (Subscription memory subscription) {
        return _subscriptions[account];
    }

    /**
     * @notice The ERC-20 address used for purchases, or 0x0 for native
     * @return erc20 address or 0x0 for native
     */
    function erc20Address() public view returns (address erc20) {
        return Currency.unwrap(_currency);
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
        // _requireOwned(tokenId); // TODO
        return string(abi.encodePacked(contractURI, "/", tokenId.toString()));
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function name() public view override returns (string memory) {
        return _name;
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
        // TODO: 0 or 1 depending on state
        return _subscriptions[account].remainingSeconds();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from == address(0)) {
            return;
        }

        uint16 tierId = _subscriptions[from].tierId;
        if (tierId != 0) {
            if (!_tiers[tierId].transferrable) {
                revert TierLib.TierTransferDisabled();
            }
        }

        if (_subscriptions[to].tokenId != 0) {
            revert InvalidTransfer();
        }

        if (to != address(0)) {
            _subscriptions[to] = _subscriptions[from];
        } else {
            // TODO
            // At a minimum decrement the tier count, and increase burn count?
        }

        delete _subscriptions[from];
    }

    //////////////////////
    // Recovery Functions
    //////////////////////

    /**
     * @notice Recover a token from the contract (unless it is the contracts denominated token)
     * @param tokenAddress the address of the token to recover
     * @param recipientAddress the address to send the tokens to
     * @param tokenAmount the amount of tokens to send
     */
    function recoverCurrency(address tokenAddress, address recipientAddress, uint256 tokenAmount) external {
        _checkOwner();
        Currency target = Currency.wrap(tokenAddress);
        if (target == _currency) {
            revert InvalidRecovery();
        }
        target.transfer(recipientAddress, tokenAmount);
    }
}
