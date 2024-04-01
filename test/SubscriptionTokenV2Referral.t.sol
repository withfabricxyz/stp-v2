// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract SubscriptionTokenV2ReferralTest is BaseTest {
    function setUp() public {
        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
        // tierParams.periodDurationSeconds = 1;
        // tierParams.pricePerPeriod = 2;
        reinitStp();
    }

    function testCreate() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.ReferralCreated(1, 500);
        stp.createReferralCode(1, 500);
        uint16 bps = stp.referralCodeBps(1);
        assertEq(bps, 500);

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidBps.selector));
        stp.createReferralCode(2, 0);
    }

    function testCreateInvalid() public prank(creator) {
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidBps.selector));
        stp.createReferralCode(1, 11000);
        stp.createReferralCode(1, 500);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.ReferralExists.selector, 1));
        stp.createReferralCode(1, 500);
    }

    function testDelete() public prank(creator) {
        stp.createReferralCode(1, 500);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.ReferralDestroyed(1);
        stp.deleteReferralCode(1);
        uint16 bps = stp.referralCodeBps(1);
        assertEq(bps, 0);
    }

    function testInvalidReferralCode() public {
        uint256 balance = charlie.balance;
        vm.startPrank(alice);
        stp.mintWithReferral{value: 1e17}(1e17, 1, charlie);
        vm.stopPrank();
        assertEq(charlie.balance, balance);
    }

    function testRewards() public {
        vm.startPrank(creator);
        stp.createReferralCode(1, 500);
        vm.stopPrank();

        uint256 balance = charlie.balance;
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidAccount.selector));
        stp.mintWithReferral{value: 1e17}(1e17, 1, address(0));

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.ReferralPayout(1, charlie, 1, 5e15);
        stp.mintWithReferral{value: 1e17}(1e17, 1, charlie);
        vm.stopPrank();
        assertEq(charlie.balance, balance + 5e15);
        assertEq(address(stp).balance, 1e17 - 5e15);
    }

    function testRewardsMintFor() public {
        uint256 balance = charlie.balance;
        vm.startPrank(alice);
        stp.mintWithReferralFor{value: 1e17}(bob, 1e17, 1, charlie);
        vm.stopPrank();
        assertEq(charlie.balance, balance);
    }

    function testRewardsErc20() public erc20 {
        vm.startPrank(creator);
        stp.createReferralCode(1, 500);
        vm.stopPrank();

        uint256 balance = token().balanceOf(charlie);
        vm.startPrank(alice);
        token().approve(address(stp), 1e17);
        stp.mintWithReferral(1e17, 1, charlie);
        vm.stopPrank();
        assertEq(token().balanceOf(charlie), balance + 5e15);
    }
}
