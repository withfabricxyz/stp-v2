// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {AccessControlled} from "./abstracts/AccessControlled.sol";

import {ERC721} from "./abstracts/ERC721.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {ISubscriptionTokenV2} from "./interfaces/ISubscriptionTokenV2.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";

import {ReferralLib} from "./libraries/ReferralLib.sol";

import {RewardCurveLib} from "./libraries/RewardCurveLib.sol";
import {SubscriberLib} from "./libraries/SubscriberLib.sol";
import {SubscriptionLib} from "./libraries/SubscriptionLib.sol";
import {TierLib} from "./libraries/TierLib.sol";
import {FeeParams, InitParams, Subscription, Tier, Tier} from "./types/Index.sol";

import {MintParams} from "./types/Params.sol";
import {CurveDetailView, CurveParams, PoolDetailView, RewardParams} from "./types/Rewards.sol";
import {ContractView, SubscriberView} from "./types/Views.sol";

import {RewardLib} from "./libraries/RewardLib.sol";
import "./types/Constants.sol";

/**
 * @title Subscription Token Protocol Version 2
 * @author Fabric Inc.
 * @notice An NFT contract which allows users to mint time and access token gated content while time remains.
 */
contract SubscriptionTokenV2 is ERC721, AccessControlled, Multicallable, Initializable, ISubscriptionTokenV2 {
    using LibString for uint256;
    using TierLib for Tier;
    using SubscriberLib for Subscription;
    using CurrencyLib for Currency;
    using SubscriptionLib for SubscriptionLib.State;
    using ReferralLib for ReferralLib.State;
    using RewardLib for RewardLib.State;
    using RewardCurveLib for CurveParams;

    /// @dev The manager role can do most things, except calls that involve money (except tier management with
    /// rewardbps)
    uint16 private constant ROLE_MANAGER = 1;

    /// @dev The agent can only grant and revoke time
    uint16 private constant ROLE_AGENT = 2;

    /// @dev The metadata URI for the contract (tokenUri is derived from this)
    string public contractURI;

    /// @dev The name of the token
    string private _name;

    /// @dev The symbol of the token
    string private _symbol;

    /// @dev The reward parameters (slash params)
    RewardParams private _rewardParams;

    /// @dev The fee parameters (collector, bips)
    FeeParams private _feeParams;

    /// @dev The denomination of the token (0 for native)
    Currency private _currency;

    /// @dev The subscription state (subscribers, tiers, etc)
    SubscriptionLib.State private _state;

    /// @dev Referral codes and rewards
    ReferralLib.State private _referrals;

    /// @dev The reward pool state (holders, balances, etc)
    RewardLib.State private _rewards;

    /// @dev The address of the account which can receive transfers via sponsored calls
    address private _transferRecipient;

    ////////////////////////////////////

    /// @dev Disable initializers on the logic contract
    constructor() {
        _disableInitializers();
    }

    /// @dev Fallback function to mint time for native token contracts
    receive() external payable {
        mintFor(msg.sender, msg.value);
    }

    function initialize(
        InitParams memory params,
        Tier memory tier,
        RewardParams memory rewards,
        CurveParams memory curve,
        FeeParams memory fees
    ) public initializer {
        // Validate core params
        if (params.owner == address(0)) revert InvalidOwner();
        if (bytes(params.name).length == 0 || bytes(params.symbol).length == 0 || bytes(params.contractUri).length == 0)
        {
            revert InvalidTokenParams();
        }

        // Validate fee params
        if (fees.bips > MAX_FEE_BPS || (fees.collector != address(0) && fees.bips == 0)) revert InvalidFeeParams();

        contractURI = params.contractUri;
        _name = params.name;
        _symbol = params.symbol;
        _currency = Currency.wrap(params.erc20TokenAddr);
        _state.supplyCap = params.globalSupplyCap;

        _feeParams = fees;
        _rewardParams = rewards;

        _rewards.createCurve(curve);
        _state.createTier(tier);
        _setOwner(params.owner);
    }

    /////////////////////////
    // Subscribing
    /////////////////////////

    /**
     * @notice Mint or renew a subscription for sender
     * @dev This is backwards compatible with the original mint function (default tier or subscribers current tier)
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mint(uint256 numTokens) external payable {
        mintFor(msg.sender, numTokens);
    }

    /**
     * @notice Mint or renew a subscription for a specific account. Intended for automated renewals.
     * @dev This is backwards compatible with the original mint function (default tier or subscribers current tier)
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mintFor(address account, uint256 numTokens) public payable {
        _purchase(account, 0, numTokens);
    }

    /**
     * @notice Mint a subscription with advanced settings
     * @dev This is the advanced minting function, which allows for setting a specific tier, referral code, and referrer
     * @param params the minting parameters
     */
    function mintAdvanced(MintParams calldata params) external payable {
        (uint256 tokenId, uint256 change) = _purchase(params.recipient, params.tierId, params.purchaseValue);

        // Referral Payout (A percentage of the remaining tokens after fees and rewards)
        if (params.referrer != address(0)) {
            uint256 payout = _referrals.computeReferralReward(params.referralCode, change);
            if (payout > 0) {
                _currency.transfer(params.referrer, payout);
                emit ReferralPayout(tokenId, params.referrer, params.referralCode, payout);
            }
        }
    }

    /////////////////////////
    // Subscriber Management
    /////////////////////////

    /**
     * @notice Refund an account, clearing the subscription and revoking any grants, and paying out a set amount
     * @dev This refunds using the creator balance. If there is not enough balance, it will fail.
     * @param account the account to refund
     * @param numTokens the amount of tokens to refund
     */
    function refund(address account, uint256 numTokens) external {
        _checkOwner();
        _checkCreatorBalance(numTokens);
        _state.refund(account, numTokens);
        _currency.transfer(account, numTokens);
    }

    /**
     * @notice Grant time to a given account
     * @param account the account to grant time to
     * @param numSeconds the number of seconds to grant
     * @param tierId the tier id to grant time to (0 to match current tier, or default for new)
     */
    function grantTime(address account, uint48 numSeconds, uint16 tierId) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);
        if (_state.subscriptions[account].tokenId == 0) _safeMint(account, _state.mint(account));
        _state.grant(account, numSeconds, tierId);
    }

    /**
     * @notice Revoke time from a given account
     * @param account the account to revoke time from
     */
    function revokeTime(address account) external {
        _checkOwnerOrRoles(ROLE_MANAGER | ROLE_AGENT);
        _state.revokeTime(account);
    }

    /////////////////////////
    // Creator Calls
    /////////////////////////

    function transferFunds(address to, uint256 amount) external {
        _checkCreatorBalance(amount);
        if (to != _transferRecipient) _checkOwner();
        emit Withdraw(to, amount);
        _currency.transfer(to, amount);
    }

    /**
     * @notice Top up the creator balance. Useful for refunds, tips, etc.
     * @param numTokens the amount of tokens to transfer
     */
    function topUp(uint256 numTokens) external payable {
        emit TopUp(_currency.capture(msg.sender, numTokens));
    }

    /**
     * @notice Update the contract metadata
     * @param uri the collection metadata URI
     */
    function updateMetadata(string memory uri) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        if (bytes(uri).length == 0) revert InvalidTokenParams();
        emit BatchMetadataUpdate(1, _state.subCount);
        contractURI = uri;
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
        if (_state.subCount > supplyCap) revert GlobalSupplyLimitExceeded();
        _state.supplyCap = supplyCap;
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
        _state.createTier(params);
    }

    /**
     * @notice Update an existing tier
     * @dev This will overwrite all existing tier parameters, so care should be taken with single field intents
     * @param tierId the id of the tier to update
     * @param params the new tier parameters
     */
    function updateTier(uint16 tierId, Tier memory params) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        _state.updateTier(tierId, params);
    }

    /////////////////////////
    // Sponsored Calls
    /////////////////////////

    /**
     * @notice Deactivate a sub, kicking them out of their tier to the 0 tier
     * @dev The intent here is to help with supply capped tiers and subscription lapses
     * @param account the account to deactivate
     */
    function deactivateSubscription(address account) external {
        _state.deactivateSubscription(account);
    }

    /////////////////////////
    // Fee Management
    /////////////////////////

    /**
     * @notice Update the fee collector address. Can be set to 0x0 to disable fees permanently.
     * @param newCollector the new fee collector address
     */
    function updateFeeRecipient(address newCollector) external {
        if (msg.sender != _feeParams.collector) revert Unauthorized();

        // Give tokens back to creator and set fee rate to 0
        if (newCollector == address(0)) _feeParams.bips = 0;
        _feeParams.collector = newCollector;
        emit FeeCollectorChange(newCollector);
    }

    /////////////////////////
    // Referral Rewards
    /////////////////////////

    /**
     * @notice Create or update a referral code for giving rewards to referrers on mint
     * @param code the unique integer code for the referral
     * @param basisPoints the reward basis points
     */
    function setReferralCode(uint256 code, uint16 basisPoints) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        _referrals.setReferral(code, basisPoints);
    }

    /**
     * @notice Fetch the reward basis points for a given referral code
     * @param code the unique integer code for the referral
     * @return bps the reward basis points
     */
    function referralCodeBps(uint256 code) external view returns (uint16 bps) {
        return _referrals.codes[code];
    }

    ////////////////////////
    // Core Internal Logic
    ////////////////////////

    /// @dev Purchase a subscription, minting a token if necessary, switching tiers if necessary
    function _purchase(
        address account,
        uint16 tierId,
        uint256 numTokens
    ) private returns (uint256 tokenId, uint256 change) {
        uint256 tokensIn = 0;
        if (numTokens > 0) tokensIn = _currency.capture(msg.sender, numTokens);

        // Mint a new token if necessary
        tokenId = _state.subscriptions[account].tokenId;
        if (tokenId == 0) {
            tokenId = _state.mint(account);
            _safeMint(account, tokenId);
        }

        // Purchase the subscription (switching tiers if necessary)
        _state.purchase(account, tokensIn, tierId);

        // Transfer fees
        uint16 bips = _feeParams.bips;
        if (bips > 0) {
            uint256 fee = (tokensIn * bips) / MAX_BPS;
            if (fee > 0) {
                _currency.transfer(_feeParams.collector, fee);
                emit FeeTransfer(_feeParams.collector, fee);
                tokensIn -= fee;
            }
        }

        // Transfer rewards if tier has rewards
        tokensIn = _issueAndAllocateRewards(account, tokensIn, _state.subscriptions[account].tierId);

        emit MetadataUpdate(tokenId);
        return (tokenId, tokensIn);
    }

    /// @dev Ensure the contract has a creator balance to cover the transfer, without dipping into rewards
    function _checkCreatorBalance(uint256 amount) private view {
        if (amount > _currency.balance() - _rewards.balance()) revert InsufficientBalance();
    }

    /// @dev Issue rewards to an account and allocate funds to the pool (if configured)
    function _issueAndAllocateRewards(address account, uint256 amount, uint16 tierId) private returns (uint256) {
        uint16 bps = _state.tiers[tierId].params.rewardBasisPoints;
        uint8 curve = _state.tiers[tierId].params.rewardCurveId;
        uint256 rewards = (amount * bps) / MAX_BPS;
        if (rewards == 0) return amount;

        // It's possible for 0 shares to be issued if the curve is not set, or the multipler is 0
        _rewards.issueWithCurve(account, rewards, curve);
        _rewards.allocate(rewards);

        return amount - rewards;
    }

    ////////////////////////
    // Rewards
    ////////////////////////

    /**
     * @notice Mint tokens to an account without payment (used for migrations, tips, etc)
     */
    function issueRewardShares(address account, uint256 numShares) external {
        _checkOwner();
        _rewards.issue(account, numShares);
    }

    /**
     * @notice Allocate rewards to the pool in the denominated currency
     * @param amount the amount of tokens (native or ERC20) to allocate
     */
    function yieldRewards(uint256 amount) external payable {
        _rewards.allocate(_currency.capture(msg.sender, amount));
    }

    /**
     * @notice Create a new reward curve
     * @param curve the curve parameters. The id is set automatically (monotonic)
     */
    function createRewardCurve(CurveParams memory curve) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        _rewards.createCurve(curve);
    }

    /**
     * @notice Transfer rewards for a given account, if any are available
     * @dev Permissionless to allow the creator or agents to transfer rewards on behalf of users
     * @param account the account of the reward holder
     */
    function transferRewardsFor(address account) public {
        _currency.transfer(account, _rewards.claimRewards(account));
    }

    /**
     * @notice Slash the reward shares for a given account if the subscription has expired and the grace period ended.
     * @dev This rebalances share value and is intended to incentivize users to renew subscriptions.
     * @param account the account to slash
     */
    function slash(address account) external {
        if (
            !_rewardParams.slashable
                || _state.subscriptions[account].expiresAt + _rewardParams.slashGracePeriod > block.timestamp
        ) revert NotSlashable();
        _rewards.burn(account);
    }

    ////////////////////////
    // Informational
    ////////////////////////

    /**
     * @notice Get details about a given reward curve
     * @param curveId the curve id to fetch
     * @return curve the curve details
     */
    function curveDetail(uint8 curveId) external view returns (CurveParams memory curve) {
        return _rewards.curves[curveId];
    }

    /**
     * @notice Get details about a particular subscription
     * @param account the account to fetch the subscription for
     * @return subscription the relevant information for a subscription
     */
    function subscriptionOf(address account) external view returns (SubscriberView memory subscription) {
        return SubscriberView({
            tierId: _state.subscriptions[account].tierId,
            tokenId: _state.subscriptions[account].tokenId,
            expiresAt: _state.subscriptions[account].expiresAt,
            rewardShares: _rewards.holders[account].numShares,
            rewardBalance: _rewards.rewardBalanceOf(account)
        });
    }

    /**
     * @notice Get details about the contract state
     * @return detail the contract details
     */
    function contractDetail() external view returns (ContractView memory detail) {
        return ContractView({
            tierCount: _state.tierCount,
            subCount: _state.subCount,
            supplyCap: _state.supplyCap,
            transferRecipient: _transferRecipient,
            currency: Currency.unwrap(_currency),
            creatorBalance: _currency.balance() - _rewards.balance(),
            numCurves: _rewards.numCurves,
            rewardShares: _rewards.totalShares,
            rewardBalance: _rewards.balance(),
            rewardSlashGracePeriod: _rewardParams.slashGracePeriod,
            rewardSlashable: _rewardParams.slashable,
            feeBps: _feeParams.bips,
            feeCollector: _feeParams.collector
        });
    }

    /**
     * @notice Get details about a given tier
     * @param tierId the tier id to fetch
     * @return tier the tier details
     */
    function tierDetail(uint16 tierId) external view returns (TierLib.State memory tier) {
        return _state.tiers[tierId];
    }

    /**
     * @notice Get the version of the protocol
     * @return version the protocol version
     */
    function stpVersion() external pure returns (uint8 version) {
        return 2;
    }

    /// @inheritdoc ISubscriptionTokenV2
    function tierBalanceOf(uint16 tierId, address account) external view returns (uint256 numSeconds) {
        Subscription memory sub = _state.subscriptions[account];
        if (sub.tierId != tierId) return 0;
        return sub.remainingSeconds();
    }

    //////////////////////
    // Overrides
    //////////////////////

    /**
     * @notice Fetch the name of the token
     * @return name the name of the token
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @notice Fetch the symbol of the token
     * @return symbol the symbol of the token
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Fetch the metadata URI for a given token
     * @dev The metadata host must be able to resolve the token ID as a path part (contractURI/${tokenId})
     * @param tokenId the tokenId to fetch the metadata URI for
     * @return uri the URI for the token
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        // _requireOwned(tokenId); // TODO
        return string(abi.encodePacked(contractURI, "/", tokenId.toString()));
    }

    /**
     * @notice Override the default balanceOf behavior to account for time remaining
     * @param account the account to fetch the balance of
     * @return numSeconds the number of seconds remaining in the subscription
     */
    function balanceOf(address account) public view override returns (uint256 numSeconds) {
        return _state.subscriptions[account].remainingSeconds();
    }

    /// @dev Prevent burning, handle soulbound tiers, and transfer subscription/reward state
    function _beforeTokenTransfer(address from, address to, uint256) internal override {
        if (_state.subscriptions[to].tokenId != 0 || to == address(0)) revert InvalidTransfer();
        if (from != address(0)) {
            uint16 tierId = _state.subscriptions[from].tierId;
            if (tierId != 0 && !_state.tiers[tierId].params.transferrable) revert TierLib.TierTransferDisabled();

            _state.subscriptions[to] = _state.subscriptions[from];
            delete _state.subscriptions[from];

            _rewards.holders[to] = _rewards.holders[from];
            delete _rewards.holders[from];
        }
    }

    /**
     * @notice Check if a token is locked
     */
    function locked(uint256 tokenId) public view override returns (bool) {
        uint16 tierId = _state.subscriptions[ownerOf(tokenId)].tierId;
        if (tierId == 0) return false;
        return !_state.tiers[tierId].params.transferrable;
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
        if (tokenAddress == Currency.unwrap(_currency)) revert InvalidRecovery();
        Currency.wrap(tokenAddress).transfer(recipientAddress, tokenAmount);
    }
}
