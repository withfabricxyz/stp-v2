// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {AccessControlled} from "./abstracts/AccessControlled.sol";

import {ERC721} from "./abstracts/ERC721.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {RewardPool} from "./RewardPool.sol";
import {IRewardPool} from "./interfaces/IRewardPool.sol";
import {ISubscriptionTokenV2} from "./interfaces/ISubscriptionTokenV2.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";

import {ReferralLib} from "./libraries/ReferralLib.sol";
import {SubscriberLib} from "./libraries/SubscriberLib.sol";
import {SubscriptionLib} from "./libraries/SubscriptionLib.sol";
import {TierLib} from "./libraries/TierLib.sol";
import {FeeParams, InitParams, Subscription, Tier, Tier} from "./types/Index.sol";

import {SubscribeParams} from "./types/Params.sol";
import {CurveParams, RewardParams} from "./types/Rewards.sol";
import {ContractView, SubscriberView} from "./types/Views.sol";

import {RewardLib} from "./libraries/RewardLib.sol";

/**
 * @title Subscription Token Protocol Version 2
 * @author Fabric Inc.
 * @notice An NFT contract which allows users to mint time and access token gated content while time remains.
 * @dev The balanceOf function returns the number of seconds remaining in the subscription. Token gated systems leverage
 *      the balanceOf function to determine if a user has the token, and if no time remains, the balance is 0. NFT
 * holders
 *      can mint additional time. The creator/owner of the contract can withdraw the funds at any point. There are
 *      additional functionalities for granting time, refunding accounts, fees, rewards, etc. This contract is designed
 * to be used with
 *      Clones, but is not designed to be upgradeable. Added functionality will come with new versions.
 */
contract SubscriptionTokenV2 is ERC721, AccessControlled, Multicallable, Initializable, ISubscriptionTokenV2 {
    using LibString for uint256;
    using TierLib for Tier;
    using SubscriberLib for Subscription;
    using CurrencyLib for Currency;
    using SubscriptionLib for SubscriptionLib.State;
    using ReferralLib for ReferralLib.State;
    using RewardLib for RewardLib.State;

    uint16 public constant ROLE_MANAGER = 1;
    uint16 public constant ROLE_AGENT = 2;

    /// @dev Maximum protocol fee basis points (12.5%)
    uint16 private constant _MAX_FEE_BIPS = 1250;

    /// @dev Maximum basis points (100%)
    uint16 private constant _MAX_BIPS = 10_000;

    /// @dev The metadata URI for the contract (tokenUri is derived from this)
    string public contractURI;

    /// @dev The name of the token
    string private _name;

    /// @dev The symbol of the token
    string private _symbol;

    /// @dev The fee parameters (collector, bips)
    FeeParams public feeParams;

    /// @dev The reward pool parameters (pollAddress (0 = disabled), and the bips)
    RewardParams public rewardParams;

    /// @dev The denomination of the token (0 for native)
    Currency private _currency;

    /// @dev The subscription state (subscribers, tiers, etc)
    SubscriptionLib.State private _state;

    /// @dev Referral codes and rewards
    ReferralLib.State private _referrals;

    /// @dev The reward pool state
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
        FeeParams memory fees
    ) public initializer {
        // Validate core params
        if (params.owner == address(0)) revert InvalidOwner();
        if (bytes(params.name).length == 0) revert InvalidName();
        if (bytes(params.symbol).length == 0) revert InvalidSymbol();
        if (bytes(params.contractUri).length == 0) revert InvalidContractUri();

        // Validate fee params
        if (fees.bips > _MAX_FEE_BIPS) revert InvalidFeeParams();
        if (fees.collector != address(0) && fees.bips == 0) revert InvalidFeeParams();

        // Validate reward params
        if (rewards.bips > _MAX_BIPS) revert InvalidRewardParams();
        if (rewards.poolAddress == address(0) && rewards.bips > 0) revert InvalidRewardParams();

        _state.createTier(tier);
        _state.supplyCap = params.globalSupplyCap;

        _rewards.curves[0] = CurveParams({
            id: 0,
            numPeriods: 6,
            formulaBase: 2,
            periodSeconds: 0,
            startTimestamp: uint48(block.timestamp),
            minMultiplier: 0
        });

        _setOwner(params.owner);
        feeParams = fees;
        rewardParams = rewards;
        _name = params.name;
        _symbol = params.symbol;
        contractURI = params.contractUri;
        _currency = Currency.wrap(params.erc20TokenAddr);
    }

    /////////////////////////
    // Subscribing
    /////////////////////////

    /**
     * @notice Mint or renew a subscription for sender
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mint(uint256 numTokens) external payable {
        mintFor(msg.sender, numTokens);
    }

    /**
     * @notice Mint or renew a subscription for a specific account. Intended for automated renewals.
     * @param account the account to mint or renew time for
     * @param numTokens the amount of ERC20 tokens or native tokens to transfer
     */
    function mintFor(address account, uint256 numTokens) public payable {
        _purchase(account, numTokens, 0);
    }

    // TODO: All possible mint configurations
    function mintAdvanced(SubscribeParams calldata params) external payable {
        (uint256 tokenId, uint256 change) = _purchase(params.recipient, params.purchaseValue, params.tierId);

        // Referral Payout
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
        // _checkCreatorBalance(numTokens); // TODO: check creator balance
        _state.refund(account, numTokens);
        // TODO: check creator balance
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
        // _checkCreatorBalance(numTokens); // TODO: check creator balance
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
        if (bytes(uri).length == 0) revert InvalidContractUri();
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
        if (_state.supplyCap > supplyCap) revert GlobalSupplyLimitExceeded();
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

    function updateTier(uint16 tierId, Tier memory params) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        _state.updateTier(tierId, params);
    }

    /////////////////////////
    // Sponsored Calls
    /////////////////////////

    function _purchase(
        address account,
        uint256 numTokens,
        uint16 tierId
    ) private returns (uint256 tokenId, uint256 change) {
        if (account == address(0)) revert InvalidAccount();

        uint256 tokensIn = _currency.capture(msg.sender, numTokens);

        // Mint a new token if necessary
        uint256 tokenId = _state.subscriptions[account].tokenId;
        if (tokenId == 0) {
            tokenId = _state.mint(account);
            _safeMint(account, tokenId);
        }

        // Purchase the subscription (switching tiers if necessary)
        _state.purchase(account, tokensIn, tierId);

        // Transfer fees and rewards
        tokensIn = _transferFees(tokensIn);
        tokensIn = _transferRewards(account, tokensIn, 0);

        return (tokenId, tokensIn);
    }

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
        if (msg.sender != feeParams.collector) revert Unauthorized();

        // Give tokens back to creator and set fee rate to 0
        if (newCollector == address(0)) feeParams.bips = 0;
        feeParams.collector = newCollector;
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

    /// @dev Allocate tokens to the fee collector
    function _transferFees(uint256 amount) private returns (uint256) {
        if (feeParams.bips == 0) return amount;
        uint256 fee = (amount * feeParams.bips) / _MAX_BIPS;
        if (fee == 0) return amount;

        _currency.transfer(feeParams.collector, fee);
        emit FeeTransfer(feeParams.collector, fee);
        return amount - fee;
    }

    function _transferRewards(address account, uint256 amount, uint8 curveId) private returns (uint256) {
        // TODO: Determine if we should issue rewards (fetch curveId, bps)
        if (rewardParams.poolAddress == address(0)) return amount;

        uint256 rewards = (amount * rewardParams.bips) / _MAX_BIPS;
        if (rewards == 0) return amount;

        _rewards.issueWithCurve(account, rewards, curveId);
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

    function createRewardCurve(CurveParams memory curve) external {
        _checkOwnerOrRoles(ROLE_MANAGER);
        _rewards.curves[curve.id] = curve;
    }

    function transferRewardsFor(address account) public {
        uint256 amount = _rewards.claimRewards(account);
        _currency.transfer(account, amount);
    }

    function slash(address account) external {
        _rewards.burn(account);
        // Now what?
    }

    ////////////////////////
    // Informational
    ////////////////////////

    // function estimatedRefund(address account) public view returns (uint256) {
    //     return _state.subscriptions[account].estimatedRefund();
    // }

    function subscriptionOf(address account) external view returns (SubscriberView memory subscription) {
        return SubscriberView({
            tierId: _state.subscriptions[account].tierId,
            secondsPurchased: _state.subscriptions[account].secondsPurchased,
            secondsGranted: _state.subscriptions[account].secondsGranted,
            tokenId: _state.subscriptions[account].tokenId,
            totalPurchased: _state.subscriptions[account].totalPurchased,
            expiresAt: _state.subscriptions[account].expiresAt(),
            estimatedRefund: _state.subscriptions[account].estimatedRefund()
        });
    }

    /// Views

    function contractDetail() external view returns (ContractView memory detail) {
        return ContractView({
            tierCount: _state.tierCount,
            subCount: _state.subCount,
            supplyCap: _state.supplyCap,
            transferRecipient: _transferRecipient,
            currency: Currency.unwrap(_currency),
            creatorBalance: _currency.balance() // TODO: subtract pool funds
        });
    }

    function tierDetail(uint16 tierId) external view returns (TierLib.State memory tier) {
        return _state.tiers[tierId];
    }

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

    /**
     * @notice Override the default balanceOf behavior to account for time remaining
     * @param account the account to fetch the balance of
     * @return numSeconds the number of seconds remaining in the subscription
     */
    function balanceOf(address account) public view override returns (uint256 numSeconds) {
        return _state.subscriptions[account].remainingSeconds();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (_state.subscriptions[to].tokenId != 0 || to == address(0)) revert InvalidTransfer();
        if (from == address(0)) return;

        uint16 tierId = _state.subscriptions[from].tierId;
        if (tierId != 0) if (!_state.tiers[tierId].params.transferrable) revert TierLib.TierTransferDisabled();
        _state.subscriptions[to] = _state.subscriptions[from];
        delete _state.subscriptions[from];
    }

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
