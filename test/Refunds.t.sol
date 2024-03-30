// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams, Subscription} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {AccessControlled} from "src/abstracts/AccessControlled.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";

contract RefundsTests is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
        poolParams.numPeriods = 0;
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testRefund() public {
        mint(alice, 1e18);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(stp.estimatedRefund(alice), 1e18);
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Refund(alice, sub.tokenId, 1e18, 1e18 / 2);
        stp.refund(alice, 0);
        assertEq(address(stp).balance, 0);
        vm.stopPrank();
    }

    function testPartialRefund() public {
        mint(alice, 1e18);
        vm.warp(block.timestamp + 2.5e17);
        assertEq(1e18 / 2, stp.estimatedRefund(alice));
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Refund(alice, 1, 5e17, 5e17 / 2);
        stp.refund(alice, 0);
        vm.stopPrank();
    }

    function testRefundNoPurchase() public prank(creator) {
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotFound.selector, bob));
        stp.refund(bob, 0);
    }

    function testRefundDecay() public prank(alice) {
        stp.mint{value: 1e18}(1e18);
        vm.warp(block.timestamp + 25e16);
        assertEq(stp.balanceOf(alice), 5e17 / 2);
        assertEq(stp.estimatedRefund(alice), 1e18 / 2);
    }

    function testRefundNoBalance() public {
        mint(alice, 1e18);
        withdraw();
        vm.startPrank(creator);
        // vm.expectRevert(abi.encodeWithSelector(PoolLib.InsufficientBalance.selector, 1e18, 0));
        stp.refund(alice, 0);
    }

    function testCustomRefund() public {
        mint(alice, 1e18);
        uint256 balance = alice.balance;
        vm.warp(block.timestamp + 5e17);
        vm.startPrank(creator);
        stp.refund(alice, 1e18);
        vm.stopPrank();
        assertEq(alice.balance, balance + 1e18);
    }

    function testRefundERC20() public erc20 {
        mint(alice, 1e18);
        uint256 beforeBalance = token().balanceOf(alice);
        vm.startPrank(creator);
        stp.refund(alice, 0);
        vm.stopPrank();
        assertEq(beforeBalance + 1e18, token().balanceOf(alice));
    }

    function testAuth() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.refund(alice, 0);
    }
}
