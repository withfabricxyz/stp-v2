// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams, TierInitParams, FeeParams, RewardParams} from "src/types/InitParams.sol";

// Test token which charges 50% fee on transfer
contract TestFeeToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        super.transfer(to, amount >> 1);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        super.transferFrom(from, to, amount >> 1);
        return true;
    }
}

contract TestERC20Token is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 numDecimals) ERC20(name, symbol) {
        _decimals = numDecimals;
        _mint(msg.sender, 1_000_000 * (10 ** uint256(numDecimals)));
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

contract SelfDestruct {
    function destroy(address recipient) public payable {
        // solc-ignore-next-line missing-receive
        selfdestruct(payable(recipient));
    }
}

abstract contract BaseTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

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

    modifier prank(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    modifier erc20() {
        stp = createERC20Sub();
        _;
    }

    address internal creator = 0xB4c79DAB8f259C7AEE6e5B2Aa729821764227E8A;
    address internal fees = 0xB4C79DAB8f259c7Aee6E5b2AA729821764227e7A;
    address internal alice = 0xb4c79DAB8f259c7Aee6E5b2aa729821864227E81;
    address internal bob = 0xB4C79DAB8f259C7aEE6E5B2aa729821864227E8a;
    address internal charlie = 0xb4C79Dab8F259C7AEe6e5b2Aa729821864227e7A;
    address internal doug = 0xB4c79dAb8f259c7aee6e5b2aa729821864227E7b;

    TierInitParams internal tierParams = TierInitParams({
        periodDurationSeconds: 2,
        maxSupply: 0,
        maxMintablePeriods: 0,
        rewardMultiplier: 1,
        paused: false,
        payWhatYouWant: false,
        allowList: 0,
        initialMintPrice: 0,
        pricePerPeriod: 4
    });

    FeeParams internal feeParams = FeeParams({collector: address(0), bips: 0});

    RewardParams internal rewardParams =
        RewardParams({bips: 0, numPeriods: 6, periodSeconds: 2, startTimestamp: 0, minMultiplier: 0});

    InitParams internal initParams = InitParams({
        name: "Meow Sub",
        symbol: "MEOW",
        contractUri: "curi",
        tokenUri: "turi",
        owner: creator,
        erc20TokenAddr: address(0)
    });

    SubscriptionTokenV2 internal stp;

    function reinitStp() public returns (SubscriptionTokenV2) {
        stp = new SubscriptionTokenV2();
        vm.store(
            address(stp),
            bytes32(uint256(0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)),
            bytes32(0)
        );
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
        return stp;
    }

    function mint(address account, uint256 amount) internal prank(account) {
        if (stp.erc20Address() != address(0)) {
            token().approve(address(stp), amount);
            stp.mint(amount);
        } else {
            stp.mint{value: amount}(amount);
        }
    }

    function list(address account) internal pure returns (address[] memory) {
        address[] memory subscribers = new address[](1);
        subscribers[0] = account;
        return subscribers;
    }

    function list(address account, address account2) internal pure returns (address[] memory) {
        address[] memory subscribers = new address[](2);
        subscribers[0] = account;
        subscribers[1] = account2;
        return subscribers;
    }

    function withdraw() internal prank(creator) {
        stp.withdraw();
    }

    function token() internal view returns (TestERC20Token) {
        return TestERC20Token(stp.erc20Address());
    }

    function createERC20Sub() public virtual returns (SubscriptionTokenV2) {
        TestERC20Token _token = new TestERC20Token("FIAT", "FIAT", 18);
        _token.transfer(alice, 1e20);
        _token.transfer(bob, 1e20);
        _token.transfer(charlie, 1e20);
        _token.transfer(creator, 1e20);
        initParams.erc20TokenAddr = address(_token);
        return reinitStp();
    }

    function createETHSub(uint256 minPurchase, uint16 feeBps, uint16 bips)
        public
        virtual
        returns (SubscriptionTokenV2 sub)
    {
        tierParams.periodDurationSeconds = uint32(minPurchase);
        tierParams.pricePerPeriod = minPurchase * 2;
        feeParams.bips = feeBps;
        feeParams.collector = feeBps > 0 ? fees : address(0);
        rewardParams.bips = bips;
        rewardParams.numPeriods = 6;
        return reinitStp();
    }

    function testIgnore() internal {}
}
