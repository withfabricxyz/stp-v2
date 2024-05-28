// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract TierSwitchingTest is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 30 days;
        tierParams.pricePerPeriod = 0.001 ether;
        stp = reinitStp();

        vm.startPrank(creator);
        stp.createTier(
            Tier({
                periodDurationSeconds: 30 days,
                maxSupply: 500,
                maxCommitmentSeconds: 0,
                rewardCurveId: 0,
                rewardBasisPoints: 0,
                paused: false,
                transferrable: false,
                initialMintPrice: 0,
                pricePerPeriod: 0.002 ether,
                startTimestamp: 0,
                endTimestamp: 0,
                gate: Gate({gateType: GateType.NONE, contractAddress: address(0), componentId: 0, balanceMin: 0})
            })
        );
        vm.stopPrank();

        deal(creator, 5 ether);
        deal(alice, 5 ether);
    }

    function testDeactivation() public {
        mint(alice, 0.001 ether);
        assertEq(stp.subscriptionOf(alice).tierId, 1);
        assertEq(stp.tierDetail(1).subCount, 1);

        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.DeactivationFailure.selector));
        stp.deactivateSubscription(alice);

        vm.warp(block.timestamp + 31 days);

        vm.expectEmit(true, true, false, true, address(stp));
        emit SubscriptionLib.SwitchTier(1, 1, 0);
        stp.deactivateSubscription(alice);
        assertEq(stp.subscriptionOf(alice).tierId, 0);
        assertEq(stp.tierDetail(1).subCount, 0);

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SubscriptionLib.SwitchTier(1, 0, 1);
        stp.mint{value: 0.001 ether}(0.001 ether);
        vm.stopPrank();
        assertEq(stp.tierDetail(1).subCount, 1);
    }

    function testUpgrade() public prank(alice) {
        stp.mint{value: 0.001 ether}(0.001 ether);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SubscriptionLib.SwitchTier(1, 1, 2);
        stp.mintAdvanced{value: 0.002 ether}(
            MintParams({tierId: 2, recipient: alice, referrer: address(0), referralCode: 0, purchaseValue: 0.002 ether})
        );

        assertEq(stp.subscriptionOf(alice).tierId, 2);
        assertApproxEqAbs(stp.balanceOf(alice), 45 days, 1);
    }

    function testInvalidTier() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierNotFound.selector, 20));
        stp.mintAdvanced{value: 0.002 ether}(
            MintParams({tierId: 20, recipient: alice, referrer: address(0), referralCode: 0, purchaseValue: 0.002 ether})
        );
    }

    function testDowngrade() public prank(alice) {
        stp.mintAdvanced{value: 0.002 ether}(
            MintParams({tierId: 2, recipient: alice, referrer: address(0), referralCode: 0, purchaseValue: 0.002 ether})
        );
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 1, recipient: alice, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );

        assertEq(stp.subscriptionOf(alice).tierId, 1);
        assertApproxEqAbs(stp.balanceOf(alice), 90 days, 1);
    }

    // Switching tiers clears the granted time
    function testGrantShift() public prank(creator) {
        stp.grantTime(alice, 30 days, 1);
        assertEq(stp.balanceOf(alice), 30 days);
        stp.grantTime(alice, 30 days, 2);
        assertEq(stp.balanceOf(alice), 30 days);
    }
}
