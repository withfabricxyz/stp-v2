// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";

contract GrantsTest is BaseTest {
    function setUp() public {
        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
        tierParams.periodDurationSeconds = 1;
        reinitStp();
    }

    function testGrant() public {
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Grant(alice, 1, 1e15, block.timestamp + 1e15);
        stp.grantTime(alice, 1e15, 1);

        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionGrantInvalidTime.selector));
        stp.grantTime(alice, 0, 1);

        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 1e15);
        assertEq(stp.refundableBalanceOf(alice), 0);
    }

    function testGrantDouble() public {
        vm.startPrank(creator);
        stp.grantTime(alice, 1e15, 1);
        vm.warp(block.timestamp + 1e16);
        stp.grantTime(alice, 1e15, 1);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 1e15);
        assertEq(stp.refundableBalanceOf(alice), 0);
    }

    function testGrantMixed() public {
        vm.startPrank(creator);
        stp.grantTime(alice, 1e15, 1);
        vm.stopPrank();
        mint(alice, 1e18);
        assertEq(stp.balanceOf(alice), 1e15 + 1e18 / 4);
        assertEq(stp.refundableBalanceOf(alice), 1e18 / 4);
    }

    function testGrantRevoke() public {
        vm.startPrank(creator);
        stp.grantTime(alice, 1e15, 1);
        stp.revokeTime(alice);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 0);
    }

    function testInvalidRevoke() public prank(creator) {
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotFound.selector, alice));
        stp.revokeTime(alice);
    }

    function testGrantRevokeWithPayment() public {
        mint(alice, 1e18);
        vm.startPrank(creator);
        stp.grantTime(alice, 1e15, 1);
        stp.revokeTime(alice);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 1e18 / 4);
    }

    function multicall() public prank(creator) {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(stp.grantTime.selector, alice, 1e15, 1);
        calls[1] = abi.encodeWithSelector(stp.grantTime.selector, bob, 1e15, 1);
        stp.multicall(calls);
        assertEq(stp.balanceOf(alice), 1e15);
        assertEq(stp.balanceOf(bob), 1e15);
    }
}
