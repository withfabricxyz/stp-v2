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
        vm.expectRevert(STPV2.NotSlashable.selector);
        stp.slash(alice);

        vm.warp(block.timestamp + 60 days); // past the grace period
        vm.expectRevert(STPV2.NotSlashable.selector);
        stp.slash(alice);
    }

    function testSlashing() public {
        rewardParams.slashable = true;
        rewardParams.slashGracePeriod = 7 days;
        stp = reinitStp();

        mint(alice, 0.101 ether);
        vm.expectRevert(STPV2.NotSlashable.selector);
        stp.slash(alice);

        vm.warp(block.timestamp + 60 days); // past the grace period
        stp.slash(alice);
        assertEq(stp.contractDetail().rewardShares, 0);
    }

    // Holder is slashed, but the transfer fails, so the creator is credited
    function testSlashingBadContract() public {
        rewardParams.slashable = true;
        rewardParams.slashGracePeriod = 0;
        stp = reinitStp();

        vm.startPrank(creator);
        stp.issueRewardShares(address(this), 100_000);
        stp.yieldRewards{value: 1 ether}(1 ether);
        assertEq(0, stp.contractDetail().creatorBalance);
        assertEq(1 ether, stp.contractDetail().rewardBalance);

        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.SlashTransferFallback(address(this), 1 ether);
        stp.slash(address(this));
        assertEq(1 ether, stp.contractDetail().creatorBalance);
        assertEq(0, stp.contractDetail().rewardBalance);
        vm.stopPrank();
    }

    function rbalance(address account) internal view returns (uint256) {
        return stp.subscriptionOf(account).rewardBalance;
    }

    function rshares(address account) internal view returns (uint256) {
        return stp.subscriptionOf(account).rewardShares;
    }

    function testOrderingNoBurn() public {
        uint256 allocation = 0.0101 ether;

        mint(alice, 0.101 ether);
        assertEq(rbalance(alice), allocation);

        mint(bob, 0.101 ether);
        assertEq(rbalance(bob), allocation / 2);

        mint(charlie, 0.101 ether);
        assertEq(rbalance(charlie), allocation / 3);
        assertEq(stp.contractDetail().rewardBalance, allocation * 3);

        // Doug should have no balance until more funds are allocated
        vm.startPrank(creator);
        stp.issueRewardShares(doug, rshares(charlie));
        vm.stopPrank();

        assertEq(rbalance(doug), 0);
        assertApproxEqAbs(rbalance(alice) + rbalance(bob) + rbalance(charlie) + rbalance(doug), allocation * 3, 3);
        assertEq(rshares(alice) + rshares(bob) + rshares(charlie) + rshares(doug), stp.contractDetail().rewardShares);

        stp.transferRewardsFor(alice);
        stp.transferRewardsFor(bob);
        stp.transferRewardsFor(charlie);

        // Some eth dust due to precision loss
        assertApproxEqAbs(stp.contractDetail().rewardBalance, 0, 3);
    }

    function testOrderingBurn() public {
        mint(alice, 0.101 ether);
        mint(bob, 0.101 ether);
        mint(charlie, 0.101 ether);
        vm.startPrank(creator);
        stp.issueRewardShares(doug, rshares(charlie));
        vm.stopPrank();

        // burn all and check balances
        vm.warp(block.timestamp + 60 days);

        uint256 aliceBalance = alice.balance + rbalance(alice);
        uint256 bobBalance = rbalance(bob);
        uint256 charlieBalance = rbalance(charlie);

        stp.slash(alice);
        assertEq(alice.balance, aliceBalance);

        assertEq(rbalance(bob), bobBalance);
        assertEq(rbalance(charlie), charlieBalance);
        assertApproxEqAbs(stp.contractDetail().rewardBalance, bobBalance + charlieBalance, 3);

        stp.slash(bob);
        stp.slash(charlie);
        stp.slash(doug);

        assertApproxEqAbs(stp.contractDetail().rewardBalance, 0, 3);
        assertEq(stp.contractDetail().rewardShares, 0);

        vm.startPrank(creator);
        stp.issueRewardShares(doug, 10_000);
        stp.yieldRewards{value: 1 ether}(1 ether);
        vm.stopPrank();

        // large allocation to doug
        assertApproxEqAbs(stp.contractDetail().rewardBalance, 1 ether, 3);
        assertApproxEqAbs(rbalance(doug), 1 ether, 3);

        stp.slash(doug);
        assertApproxEqAbs(stp.contractDetail().rewardBalance, 0, 3);

        vm.startPrank(creator);
        stp.issueRewardShares(doug, 10_000);
        stp.yieldRewards{value: 1 ether}(1 ether);
        stp.issueRewardShares(alice, 30_000); // 25% of shares
        vm.stopPrank();

        assertApproxEqAbs(rbalance(alice), 0, 3);
        assertApproxEqAbs(rbalance(doug), (1 ether), 3);

        stp.yieldRewards{value: 1 ether}(1 ether);
        assertApproxEqAbs(rbalance(doug) + rbalance(alice), (2 ether), 3);
        assertApproxEqAbs(rbalance(alice), (0.75 ether), 3);

        stp.slash(doug);
        assertApproxEqAbs(rbalance(alice), (0.75 ether), 3);
        assertEq(rbalance(doug), 0);
        assertApproxEqAbs(stp.contractDetail().rewardBalance, (0.75 ether), 3);
        assertEq(stp.contractDetail().rewardBalance + stp.contractDetail().creatorBalance, address(stp).balance);
        assertApproxEqAbs(
            stp.contractDetail().rewardBalance + stp.contractDetail().creatorBalance,
            (0.75 ether) + (0.303 ether) - (0.0303 ether),
            2
        );
    }
}
