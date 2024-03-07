// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/InitParams.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";

contract SubscriptionTokenV2GrantsTest is BaseTest {
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
        stp.grantTime(list(alice), 1e15);

        address[] memory subscribers = new address[](0);
        vm.expectRevert("No accounts to grant time to");
        stp.grantTime(subscribers, 1e15);

        vm.expectRevert("Seconds to add must be > 0");
        stp.grantTime(list(alice), 0);

        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 1e15);
        assertEq(stp.refundableBalanceOf(alice), 0);
    }

    function testGrantDouble() public {
        vm.startPrank(creator);
        stp.grantTime(list(alice), 1e15);
        vm.warp(block.timestamp + 1e16);
        stp.grantTime(list(alice), 1e15);
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 1e15);
        assertEq(stp.refundableBalanceOf(alice), 0);
    }

    function testGrantMixed() public {
        vm.startPrank(creator);
        stp.grantTime(list(alice), 1e15);
        vm.stopPrank();
        mint(alice, 1e18);
        assertEq(stp.balanceOf(alice), 1e15 + 1e18 / 4);
        assertEq(stp.refundableBalanceOf(alice), 1e18 / 4);
    }

    function testGrantRefund() public {
        vm.startPrank(creator);
        stp.grantTime(list(alice), 1e15);
        stp.refund(0, list(alice));
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 0);
    }

    function testGrantRefundMixed() public {
        mint(alice, 1e18);
        vm.startPrank(creator);
        stp.grantTime(list(alice), 1e15);
        stp.refund(0, list(alice));
        vm.stopPrank();
        assertEq(stp.balanceOf(alice), 0);
    }
}
