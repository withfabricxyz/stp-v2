// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RefundsTests is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 30 days;
        tierParams.pricePerPeriod = 0.001 ether;
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testRefund() public {
        mint(alice, 0.001 ether);
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SubscriptionLib.Refund(1, 0.001 ether, 30 days);
        stp.refund(alice, 0.001 ether);
        assertEq(address(stp).balance, 0);
        vm.stopPrank();
    }

    function testFundPast() public {
        mint(alice, 0.001 ether);
        vm.warp(block.timestamp + 31 days);
        vm.startPrank(creator);
        stp.refund(alice, 0.001 ether);
        assertEq(address(stp).balance, 0);
        vm.stopPrank();
    }

    function testPartialRefund() public {
        mint(alice, 0.001 ether);
        vm.warp(block.timestamp + 15 days);
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SubscriptionLib.Refund(1, 0.001 ether / 2, 15 days);
        stp.refund(alice, 0.0005 ether);
        vm.stopPrank();
    }

    function testRefundNoPurchase() public prank(creator) {
        stp.topUp{value: 1 ether}(1 ether);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotFound.selector));
        stp.refund(bob, 0.001 ether);
    }

    function testRefundNoBalance() public {
        mint(alice, 0.001 ether);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(STPV2.InsufficientBalance.selector));
        stp.refund(alice, 0.002 ether);
        vm.stopPrank();
    }

    function testRefundERC20() public erc20 {
        mint(alice, 0.001 ether);
        uint256 beforeBalance = token().balanceOf(alice);
        vm.startPrank(creator);
        stp.refund(alice, 0.001 ether);
        vm.stopPrank();
        assertEq(beforeBalance + 0.001 ether, token().balanceOf(alice));
    }

    function testAuth() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.refund(alice, 0);
    }
}
