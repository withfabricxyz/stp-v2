// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract GrantsTest is BaseTest {
    using SubscriberLib for Subscription;

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
        emit SubscriptionLib.Grant(1, 90 days, uint48(block.timestamp + 90 days));
        stp.grantTime(alice, 90 days, 1);

        vm.expectRevert(abi.encodeWithSelector(SubscriberLib.SubscriptionGrantInvalidTime.selector));
        stp.grantTime(alice, 0, 1);

        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 90 days);
        assertEq(stp.subscriptionOf(alice).tierId, 1);
    }

    function testGrantDouble() public {
        vm.startPrank(creator);
        stp.grantTime(alice, 90 days, 1);
        vm.warp(block.timestamp + 91 days);
        stp.grantTime(alice, 30 days, 1);
        stp.grantTime(alice, 60 days, 1);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 90 days);
        assertEq(stp.subscriptionOf(alice).expiresAt, block.timestamp + 90 days);
    }

    function testGrantMixed() public {
        vm.startPrank(creator);
        stp.grantTime(alice, 90 days, 1);
        vm.stopPrank();
        mint(alice, 1e5);
        assertEq(stp.balanceOf(alice), 90 days + 1e5 / 4);
    }

    function testGrantRevoke() public {
        vm.startPrank(creator);
        stp.grantTime(alice, 90 days, 1);
        stp.revokeTime(alice);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 0);
    }

    function testInvalidRevoke() public prank(creator) {
        stp.revokeTime(alice);
        assertEq(stp.balanceOf(alice), 0);
    }

    function testGrantRevokeWithPayment() public {
        mint(alice, 1e5);
        vm.startPrank(creator);
        stp.grantTime(alice, 90 days, 1);
        stp.revokeTime(alice);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 1e5 / 4);
    }

    function multicall() public prank(creator) {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(stp.grantTime.selector, alice, 90 days, 1);
        calls[1] = abi.encodeWithSelector(stp.grantTime.selector, bob, 90 days, 1);
        stp.multicall(calls);
        assertEq(stp.balanceOf(alice), 90 days);
        assertEq(stp.balanceOf(bob), 90 days);
    }
}
