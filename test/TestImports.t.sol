// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC721} from "solady/tokens/ERC721.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

//////////// Project Imports ////////////

import {RewardPool} from "src/RewardPool.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {AccessControlled} from "src/abstracts/AccessControlled.sol";
import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";

import {Currency, CurrencyLib} from "src/libraries/CurrencyLib.sol";
import {GateLib} from "src/libraries/GateLib.sol";
import {RewardCurveLib} from "src/libraries/RewardCurveLib.sol";
import {RewardLib} from "src/libraries/RewardLib.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";

import {SubscriberLib} from "src/libraries/SubscriberLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {DeployParams, FactoryFeeConfig} from "src/types/Factory.sol";
import {FeeParams, Gate, GateType, InitParams, Subscription, Subscription, Tier} from "src/types/Index.sol";
import {CurveParams, Holder, RewardParams, RewardPoolParams} from "src/types/Rewards.sol";
import {SubscriberView} from "src/types/Views.sol";

contract TestERC1155Token is ERC1155 {
    constructor() ERC1155("test") {
        _mint(msg.sender, 1, 1, "token");
    }

    function mint(address account, uint256 id, uint256 amount) external {
        _mint(account, id, amount, "");
    }

    function testIgnore() internal {}
}

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

    function testIgnore() internal {}
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

    function testIgnore() internal {}
}

contract SelfDestruct {
    function destroy(address recipient) public payable {
        // solc-ignore-next-line missing-receive
        selfdestruct(payable(recipient));
    }

    function testIgnore() internal {}
}

abstract contract BaseTest is Test {
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

    Tier internal tierParams = Tier({
        periodDurationSeconds: 2,
        maxSupply: 0,
        maxCommitmentSeconds: 0,
        rewardMultiplier: 1,
        paused: false,
        transferrable: true,
        initialMintPrice: 0,
        pricePerPeriod: 4,
        startTimestamp: 0,
        endTimestamp: 0,
        gate: Gate({gateType: GateType.NONE, contractAddress: address(0), componentId: 0, balanceMin: 0})
    });

    FeeParams internal feeParams = FeeParams({collector: address(0), bips: 0});

    RewardParams internal rewardParams = RewardParams({bips: 0, poolAddress: address(0)});

    InitParams internal initParams = InitParams({
        name: "Meow Sub",
        symbol: "MEOW",
        contractUri: "curi",
        owner: creator,
        erc20TokenAddr: address(0),
        globalSupplyCap: 0
    });

    SubscriptionTokenV2 internal stp;

    function reinitStp() public returns (SubscriptionTokenV2) {
        stp = new SubscriptionTokenV2();
        vm.store(
            address(stp),
            bytes32(uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132)),
            bytes32(0)
        );
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
        return stp;
    }

    function mint(address account, uint256 amount) internal prank(account) {
        if (stp.contractDetail().currency != address(0)) {
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
        stp.transferFunds(creator, stp.contractDetail().creatorBalance);
    }

    function token() internal view returns (TestERC20Token) {
        return TestERC20Token(stp.contractDetail().currency);
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

    function createETHSub(
        uint256 minPurchase,
        uint16 feeBps,
        uint16 bips
    ) public virtual returns (SubscriptionTokenV2 sub) {
        tierParams.periodDurationSeconds = uint32(minPurchase);
        tierParams.pricePerPeriod = minPurchase * 2;
        feeParams.bips = feeBps;
        feeParams.collector = feeBps > 0 ? fees : address(0);
        // poolParams.bips = bips;
        // poolParams.numPeriods = 6;
        return reinitStp();
    }

    function defaultCurveParams() internal pure returns (CurveParams memory) {
        return
            CurveParams({id: 0, numPeriods: 6, periodSeconds: 2, startTimestamp: 0, minMultiplier: 0, formulaBase: 2});
    }

    function defaultPoolParams() internal pure returns (RewardPoolParams memory) {
        return RewardPoolParams({
            // name: "name",
            // symbol: "symbol",
            currencyAddress: address(0),
            slashGracePeriod: 0,
            // transferUnlockDate: 0,
            // acceptMultipliers: true,
            // trustedMintOnly: true,
            slashable: false
        });
    }

    function testIgnore() internal {}
}
