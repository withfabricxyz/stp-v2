// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract ReferralTests is BaseTest {
    function setUp() public {
        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
        reinitStp();
    }

    function testCreateAndDestroy() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ReferralLib.ReferralSet(1, 500);
        stp.setReferralCode(1, 500);
        assertEq(stp.referralCodeBps(1), 500);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ReferralLib.ReferralDestroyed(1);
        stp.setReferralCode(1, 0);
        assertEq(stp.referralCodeBps(1), 0);
    }

    function testCreateInvalid() public prank(creator) {
        vm.expectRevert(abi.encodeWithSelector(InvalidBasisPoints.selector));
        stp.setReferralCode(1, 11_000);
    }

    function testInvalidReferralCode() public {
        uint256 balance = charlie.balance;
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 1, recipient: bob, referrer: charlie, referralCode: 10, purchaseValue: 0.001 ether})
        );
        assertEq(charlie.balance, balance);
    }

    function testRewards() public {
        vm.startPrank(creator);
        stp.setReferralCode(1, 500);
        vm.stopPrank();

        uint256 balance = charlie.balance;

        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.ReferralPayout(1, charlie, 1, 5e15);
        stp.mintAdvanced{value: 0.1 ether}(
            MintParams({tierId: 1, recipient: bob, referrer: charlie, referralCode: 1, purchaseValue: 0.1 ether})
        );
        vm.stopPrank();
        assertEq(charlie.balance, balance + 5e15);
        assertEq(address(stp).balance, 1e17 - 5e15);
    }
}
