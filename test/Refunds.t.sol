// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RefundsTests is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 30 days;
        tierParams.pricePerPeriod = 0.001 ether;
        poolParams.numPeriods = 0;
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testRefund() public {
        mint(alice, 0.001 ether);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(stp.estimatedRefund(alice), 0.001 ether);
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Refund(alice, sub.tokenId, 0.001 ether, 30 days);
        stp.refund(alice, 0);
        assertEq(address(stp).balance, 0);
        vm.stopPrank();
    }

    function testPartialRefund() public {
        mint(alice, 0.001 ether);
        vm.warp(block.timestamp + 15 days);
        assertEq(0.001 ether / 2, stp.estimatedRefund(alice));
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Refund(alice, 1, 0.001 ether / 2, 15 days);
        stp.refund(alice, 0);
        vm.stopPrank();
    }

    function testRefundNoPurchase() public prank(creator) {
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotFound.selector, bob));
        stp.refund(bob, 0);
    }

    function testRefundNoBalance() public {
        mint(alice, 0.001 ether);
        withdraw();
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        stp.refund(alice, 0);
    }

    function testCustomRefund() public {
        mint(alice, 0.001 ether);
        uint256 balance = alice.balance;
        vm.warp(block.timestamp + 20 days);
        vm.startPrank(creator);
        stp.refund(alice, 0.001 ether);
        vm.stopPrank();
        assertEq(alice.balance, balance + 0.001 ether);
    }

    function testRefundERC20() public erc20 {
        mint(alice, 0.001 ether);
        uint256 beforeBalance = token().balanceOf(alice);
        vm.startPrank(creator);
        stp.refund(alice, 0);
        vm.stopPrank();
        assertEq(beforeBalance + 0.001 ether, token().balanceOf(alice));
    }

    function testAuth() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.refund(alice, 0);
    }
}
