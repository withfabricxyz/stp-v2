// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RewardsTest is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 30 days;
        tierParams.pricePerPeriod = 0.001 ether;
        tierParams.initialMintPrice = 0.1 ether;
        tierParams.rewardCurveId = 0;
        tierParams.rewardBasisPoints = 1000; // 10%
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testCurve() public prank(creator) {
        stp.createRewardCurve(
            CurveParams({numPeriods: 6, periodSeconds: 86_400, startTimestamp: 0, minMultiplier: 0, formulaBase: 2})
        );
        assertEq(stp.curveDetail(1).numPeriods, 6);
        assertEq(stp.contractDetail().numCurves, 2);
    }

    function testRewardTransfer() public {
        mint(alice, 0.101 ether);
        uint256 expectedRewards = 0.0101 ether;
        assertEq(stp.contractDetail().rewardBalance, expectedRewards);
        stp.transferRewardsFor(alice);
        assertEq(stp.contractDetail().rewardBalance, 0 ether);
    }

    function testYield() public {
        mint(alice, 0.101 ether);
        stp.yieldRewards{value: 1 ether}(1 ether);
        assertEq(stp.contractDetail().rewardBalance, 1.0101 ether);
    }

    // Should be grant?
    function testIssue() public {
        vm.expectRevert(AccessControlled.NotAuthorized.selector);
        stp.issueRewardShares(alice, 100);

        vm.startPrank(creator);
        stp.issueRewardShares(alice, 100);
        assertEq(stp.contractDetail().rewardShares, 100);
        vm.stopPrank();
    }

    function testSlashingDisabled() public {
        rewardParams.slashable = false;
        stp = reinitStp();

        mint(alice, 0.101 ether);
        vm.expectRevert(ISubscriptionTokenV2.NotSlashable.selector);
        stp.slash(alice);

        vm.warp(block.timestamp + 60 days); // past the grace period
        vm.expectRevert(ISubscriptionTokenV2.NotSlashable.selector);
        stp.slash(alice);
    }

    function testSlashing() public {
        rewardParams.slashable = true;
        rewardParams.slashGracePeriod = 7 days;
        stp = reinitStp();

        mint(alice, 0.101 ether);
        vm.expectRevert(ISubscriptionTokenV2.NotSlashable.selector);
        stp.slash(alice);

        vm.warp(block.timestamp + 60 days); // past the grace period
        stp.slash(alice);
        assertEq(stp.contractDetail().rewardShares, 0);
    }
}
