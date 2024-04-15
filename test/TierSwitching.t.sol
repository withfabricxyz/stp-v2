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
                maxSupply: 0,
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
        assertFalse(stp.locked(1));

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
            MintParams({
                tierId: 2,
                numPeriods: 1,
                recipient: alice,
                referrer: address(0),
                referralCode: 0,
                purchaseValue: 0.002 ether
            })
        );

        // TODO: Check on timing
        assertEq(stp.subscriptionOf(alice).tierId, 2);
        assertTrue(stp.locked(1));
    }

    function testDowngrade() public {}

    function testGrantShift() public {}
}
