// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/InitParams.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AllocationLib} from "src/libraries/AllocationLib.sol";

contract SubscriptionTokenV2RefundsTest is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
        rewardParams.numRewardHalvings = 0;
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testRefund() public {
        mint(alice, 1e18);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Refund(alice, tokenId, 1e18, 1e18 / 2);
        (creator, 2e18);
        stp.refund(0, list(alice));
        assertEq(address(stp).balance, 0);

        address[] memory subscribers = new address[](0);
        vm.expectRevert("No accounts to refund");
        stp.refund(0, subscribers);

        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.refund(0, list(alice));
    }

    function testPartialRefund() public {
        mint(alice, 1e18);
        vm.warp(block.timestamp + 2.5e17);
        assertEq(5e17 / 2, stp.refundableBalanceOf(alice));
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Refund(alice, 1, 5e17, 5e17 / 2);
        stp.refund(0, list(alice));
        vm.stopPrank();
    }

    function testRefundNoPurchase() public {
        mint(alice, 1e18);
        uint256 balance = bob.balance;
        vm.startPrank(creator);
        stp.refund(0, list(bob));
        vm.stopPrank();
        assertEq(balance, bob.balance);
    }

    function testInvalidRefund() public {
        mint(alice, 1e18);
        vm.startPrank(creator);
        vm.expectRevert("Unexpected value transfer");
        stp.refund{value: 1}(0, list(alice));
        vm.stopPrank();
    }

    function testRefundCalc() public {
        mint(alice, 1e18);
        assertEq(1e18, stp.refundableTokenBalanceOfAll(list(alice, bob)));
        mint(bob, 1e18);
        assertEq(2e18, stp.refundableTokenBalanceOfAll(list(alice, bob)));
    }

    function testRefundDecay() public prank(alice) {
        stp.mint{value: 1e18}(1e18);
        vm.warp(block.timestamp + 25e16);
        assertEq(stp.balanceOf(alice), 5e17 / 2);
        assertEq(stp.refundableBalanceOf(alice), 5e17 / 2);
    }

    function testRefundNoBalance() public {
        mint(alice, 1e18);
        withdraw();
        assertFalse(stp.canRefund(list(alice)));
        vm.startPrank(creator);
        vm.expectRevert("Insufficient balance for refund");
        stp.refund(0, list(alice));

        // Send eth to contract while refunding
        vm.expectEmit(true, true, false, true, address(stp));
        emit RefundTopUp(2e18);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Refund(alice, 1, 1e18, 1e18 / 2);
        stp.refund{value: 2e18}(2e18, list(alice));
        assertEq(1e18, address(stp).balance);
        assertEq(1e18, stp.creatorBalance());
        vm.stopPrank();
    }

    /// ERC20

    function testERC20Mint() public erc20 prank(alice) {
        assert(stp.erc20Address() != address(0));
        assertEq(token().balanceOf(alice), 1e20);
        token().approve(address(stp), 1e18);
        stp.mint(1e18);
        assertEq(token().balanceOf(address(stp)), 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        assertEq(stp.ownerOf(tokenId), alice);
    }

    function testMintInvalidERC20() public erc20 prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(AllocationLib.NativeTokensNotAcceptedForERC20Subscriptions.selector));
        stp.mint{value: 1e17}(1e18);
        vm.expectRevert(
            abi.encodeWithSelector(AllocationLib.InsufficientBalanceOrAllowance.selector, token().balanceOf(alice), 0)
        );
        stp.mint(1e18);
    }

    function testERC20FeeTakingToken() public {
        TestFeeToken _token = new TestFeeToken("FIAT", "FIAT", 1e21);
        _token.transfer(alice, 1e20);
        initParams.erc20TokenAddr = address(_token);
        reinitStp();
        vm.startPrank(alice);
        _token.approve(address(stp), 1e18);
        stp.mint(1e18);
        assertEq(stp.balanceOf(alice), 1e18 / 2 / 2);
        vm.stopPrank();
    }

    function testWithdrawERC20() public erc20 {
        mint(alice, 1e18);
        mint(bob, 1e18);

        uint256 beforeBalance = token().balanceOf(creator);
        vm.startPrank(creator);
        assertEq(stp.creatorBalance(), 2e18);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Withdraw(creator, 2e18);
        stp.withdraw();
        assertEq(stp.creatorBalance(), 0);
        assertEq(stp.totalCreatorEarnings(), 2e18);

        vm.expectRevert("No Balance");
        stp.withdraw();
        vm.stopPrank();

        assertEq(beforeBalance + 2e18, token().balanceOf(creator));
    }

    function testRefundERC20() public erc20 {
        mint(alice, 1e18);
        uint256 beforeBalance = token().balanceOf(alice);
        vm.startPrank(creator);
        stp.refund(0, list(alice));
        vm.stopPrank();
        assertEq(beforeBalance + 1e18, token().balanceOf(alice));
    }

    function testRefundERC20AfterWithdraw() public erc20 {
        mint(alice, 1e18);
        vm.startPrank(creator);
        stp.withdraw();
        vm.expectRevert("Insufficient balance for refund");
        stp.refund(0, list(alice));
        vm.stopPrank();
    }

    function testReconcile() public erc20 prank(creator) {
        // No-op
        stp.reconcileERC20Balance();

        token().transfer(address(stp), 1e17);
        stp.reconcileERC20Balance();
        assertEq(stp.creatorBalance(), 1e17);
    }

    function testRecoverERC20Self() public erc20 prank(creator) {
        address addr = stp.erc20Address();
        vm.expectRevert("Cannot recover subscription token");
        stp.recoverERC20(addr, alice, 1e17);
    }

    function testRecoverERC20() public prank(creator) {
        TestERC20Token token = new TestERC20Token("FIAT", "FIAT", 18);
        token.transfer(address(stp), 1e17);
        stp.recoverERC20(address(token), alice, 1e17);
        assertEq(token.balanceOf(alice), 1e17);
    }

    function testReconcileNative() public prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        // no op
        stp.reconcileNativeBalance();

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);
        assertEq(stp.creatorBalance(), 0);
        stp.reconcileNativeBalance();
        assertEq(stp.creatorBalance(), 1e18);

        vm.expectRevert("Not supported, use reconcileNativeBalance");
        stp.recoverNativeTokens(bob);
    }

    function testRecoverNative() public erc20 prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        vm.expectRevert("No balance to recover");
        stp.recoverNativeTokens(bob);

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);

        vm.expectRevert("Failed to transfer Ether");
        stp.recoverNativeTokens(address(this));

        stp.recoverNativeTokens(bob);
        assertEq(stp.creatorBalance(), 0);
        assertEq(bob.balance, 1e19 + 1e18);
    }

    /// Supply Cap
    function testSupplyCap() public {
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SupplyCapChange(1);
        stp.setSupplyCap(1);
        (uint256 count, uint256 supply) = stp.supplyDetail();
        assertEq(supply, 1);
        assertEq(count, 0);
        vm.stopPrank();
        mint(alice, 1e18);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.TierHasNoSupply.selector, 1));
        stp.mint{value: 1e18}(1e18);
        vm.stopPrank();

        vm.startPrank(creator);
        stp.setSupplyCap(0);
        vm.stopPrank();

        mint(bob, 1e18);
        vm.startPrank(creator);
        vm.expectRevert("Supply cap must be >= current count or 0");
        stp.setSupplyCap(1);
        vm.stopPrank();
    }
}
