// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
import {RewardLib} from "src/libraries/RewardLib.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";

contract RewardsTest is BaseTest {
    function setUp() public {
        deal(alice, 1e20);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(doug, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);

        stp = createETHSub(2592000, 0, 500);
        tierParams.periodDurationSeconds = 2592000;
        tierParams.pricePerPeriod = 2592000 * 2;
        rewardParams.bips = 500;
        rewardParams.numPeriods = 6;
        rewardParams.periodSeconds = 2592000;
        reinitStp();
    }

    function testSingleHalving() public {
        rewardParams.bips = 500;
        rewardParams.numPeriods = 1;
        rewardParams.periodSeconds = 10;
        reinitStp();
        assertEq(stp.rewardMultiplier(), 2);
        vm.warp(block.timestamp + 11);
        assertEq(stp.rewardMultiplier(), 1);
        vm.warp(block.timestamp + 21);
        assertEq(stp.rewardMultiplier(), 0);
    }

    function testDecay() public {
        uint256 halvings = 6;
        for (uint256 i = 0; i <= halvings; i++) {
            vm.warp((stp.minPurchaseSeconds() * i) + 1);
            assertEq(stp.rewardMultiplier(), (2 ** (halvings - i)));
        }
        vm.warp((stp.minPurchaseSeconds() * 7) + 1);
        assertEq(stp.rewardMultiplier(), 0);
    }

    function testRewardPointPool() public prank(alice) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.RewardsAllocated(1e18 * 500 / 10_000);
        stp.mint{value: 1e18}(1e18);
        (,, uint256 points,) = stp.subscriptionOf(alice);
        assertEq(stp.rewardMultiplier(), 64);
        assertEq(points, 1e18 * 64);
        assertEq(stp.totalRewardPoints(), 1e18 * 64);

        // 2nd allocation
        stp.mint{value: 1e18}(1e18);
        (,, points,) = stp.subscriptionOf(alice);
        assertEq(points, 2e18 * 64);
        assertEq(stp.totalRewardPoints(), 2e18 * 64);
    }

    function testDisabledWithdraw() public {
        stp = createETHSub(2592000, 0, 0);
        mint(alice, 1e18);
        withdraw();
        assertEq(0, stp.rewardBalanceOf(alice));
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.withdrawRewards();
        vm.stopPrank();
    }

    function testRewardPointWithdraw() public {
        mint(alice, 1e18);
        uint256 preBalance = creator.balance;
        withdraw();
        assertEq(preBalance + 1e18 - ((1e18 * 500) / 10_000), creator.balance);
        vm.startPrank(alice);
        preBalance = alice.balance;
        assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(alice));
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.RewardWithdraw(alice, (1e18 * 500) / 10_000);
        stp.withdrawRewards();
        assertEq(preBalance + (1e18 * 500) / 10_000, alice.balance);
        assertEq(0, stp.rewardBalanceOf(alice));
        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.withdrawRewards();
        vm.stopPrank();

        mint(bob, 1e18);
        withdraw();
        assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(bob));
        assertEq(0, stp.rewardBalanceOf(alice));

        mint(charlie, 1e18);
        withdraw();
        assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(bob));
        assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(charlie));
        assertEq(0, stp.rewardBalanceOf(alice));
    }

    function testRewardPointWithdrawStepped() public {
        mint(alice, 1e18);
        vm.warp(31 days);
        mint(bob, 1e18);
        vm.warp(61 days);
        mint(charlie, 1e18);
        vm.warp(91 days);
        mint(doug, 1e18);

        withdraw();
        uint256 totalPool = (4e18 * 500) / 10_000;

        assertEq((totalPool * 64) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(alice));
        assertEq((totalPool * 32) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(bob));
        assertEq((totalPool * 16) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(charlie));
        assertEq((totalPool * 8) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(doug));

        vm.startPrank(alice);
        stp.withdrawRewards();
        vm.stopPrank();
        assertEq(0, stp.rewardBalanceOf(alice));

        mint(doug, 1e18);
        withdraw();

        uint256 withdrawn = (totalPool * 64) / (64 + 32 + 16 + 8);
        totalPool = (5e18 * 500) / 10_000;
        assertEq((totalPool * 64) / (64 + 32 + 16 + 8 + 8) - withdrawn, stp.rewardBalanceOf(alice));

        vm.startPrank(alice);
        stp.withdrawRewards();
        vm.stopPrank();
    }

    function testWithdrawExpired() public {
        mint(alice, 2592000 * 2);
        vm.warp(60 days);
        withdraw();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotActive.selector));
        stp.withdrawRewards();
        vm.stopPrank();
    }

    function testSlashingNoRewards() public {
        rewardParams.bips = 0;

        reinitStp();

        mint(alice, 2592000 * 2);
        mint(bob, 1e8);

        vm.warp(2592000 * 3);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardsDisabled.selector));
        stp.slashRewards(alice);
        vm.stopPrank();
    }

    function testSlashing() public {
        mint(alice, 2592000 * 2);
        mint(bob, 1e8);

        uint256 beforePoints = stp.totalRewardPoints();
        (,, uint256 alicePoints,) = stp.subscriptionOf(alice);

        vm.warp(2592000 * 3);
        vm.startPrank(bob);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.RewardPointsSlashed(alice, bob, alicePoints);
        stp.slashRewards(alice);
        vm.stopPrank();

        uint256 afterPoints = stp.totalRewardPoints();
        (,, uint256 aliceAfterPoints,) = stp.subscriptionOf(alice);

        assertEq(0, aliceAfterPoints);
        assertEq(afterPoints, beforePoints - alicePoints);
    }

    function testSlashingWithdraws() public {
        mint(alice, 2592000 * 2);
        vm.warp((stp.minPurchaseSeconds() * 3) + 1);
        mint(bob, 1e8);

        // Allocate rewards
        withdraw();
        vm.startPrank(bob);
        stp.withdrawRewards();
        assertEq(stp.rewardBalanceOf(bob), 0);
        stp.slashRewards(alice);
        assertEq(stp.rewardBalanceOf(bob), stp.rewardPoolBalance());
        stp.withdrawRewards();
        vm.stopPrank();
    }

    function testDoubleSlash() public {
        mint(alice, 2592000 * 2);
        vm.warp((stp.minPurchaseSeconds() * 3) + 1);
        mint(bob, 1e8);
        withdraw();
        vm.startPrank(bob);
        stp.slashRewards(alice);
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardSlashingNotPossible.selector));
        stp.slashRewards(alice);
        vm.stopPrank();
    }

    function testSlashingActive() public {
        mint(alice, 2592000 * 2);
        mint(bob, 1e8);
        vm.startPrank(alice);
        (,,, uint256 expiresAt) = stp.subscriptionOf(alice);
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardSlashingNotReady.selector, expiresAt));
        stp.slashRewards(alice);
        vm.warp(60 days);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotActive.selector));
        stp.slashRewards(alice);
        vm.stopPrank();
    }

    function testNoPointPool() public {
        vm.warp(365 days);
        // first mint is after reward points go to 0
        mint(alice, 1e18);
        withdraw();
        assertEq(0, stp.rewardPoolBalance());
    }

    function testRewardPoolToCreator() public {
        mint(alice, 1e18);
        withdraw();
        assertEq(5e16, stp.rewardPoolBalance());
        assertEq(5e16, stp.rewardBalanceOf(alice));

        (,,, uint256 expires) = stp.subscriptionOf(alice);
        vm.warp(expires * 5);
        mint(bob, 1e18);
        vm.startPrank(bob);
        stp.slashRewards(alice);
        vm.stopPrank();

        assertEq(0, stp.rewardPoolBalance());
        // total points -> 0, so remaining rewards go back to creator
        assertEq(1e18 + 5e16, stp.creatorBalance());
    }

    function testSlashPostWithdraw() public {
        mint(alice, 3e8);
        mint(bob, 2e8);
        mint(charlie, 1e8);

        uint256 aliceBalance = stp.rewardBalanceOf(alice);
        assertEq(aliceBalance, 15000000);

        // withdraw rewards for alice
        vm.startPrank(charlie);
        stp.withdrawRewards();
        vm.stopPrank();

        // Go past expiration
        (,,, uint256 expires) = stp.subscriptionOf(charlie);
        vm.warp(expires + expires + 1);

        // slash charlie
        vm.startPrank(alice);
        stp.slashRewards(charlie);
        vm.stopPrank();

        assertEq(stp.rewardBalanceOf(alice), aliceBalance);
        assertEq(stp.rewardBalanceOf(charlie), 0);
    }

    function testSlashPostWithdrawDistanceFuture() public {
        mint(alice, 3e8);
        mint(bob, 2e8);
        mint(charlie, 1e8);

        uint256 aliceBalance = stp.rewardBalanceOf(alice);
        assertEq(aliceBalance, 15000000);

        // withdraw rewards for charlie
        vm.startPrank(charlie);
        stp.withdrawRewards();
        vm.stopPrank();

        // Go far past expiration
        (,,, uint256 expires) = stp.subscriptionOf(charlie);
        vm.warp(expires + expires + 1e6);

        // slash charlie
        vm.startPrank(alice);
        stp.slashRewards(charlie);
        vm.stopPrank();

        assertEq(stp.rewardBalanceOf(alice), aliceBalance);

        (,, uint256 charliePoints,) = stp.subscriptionOf(charlie);
        assertEq(charliePoints, 0);
    }

    function testSlashResub() public {
        mint(alice, 1e7);
        mint(bob, 3e8);
        uint256 aliceBalance = stp.rewardBalanceOf(alice);
        assertEq(aliceBalance, 500000);

        // withdraw rewards for charlie
        vm.startPrank(alice);
        stp.withdrawRewards();
        vm.stopPrank();

        // Go far past expiration
        (,,, uint256 expires) = stp.subscriptionOf(alice);
        vm.warp((expires * 150) / 90);

        // slash charlie
        mint(bob, 3e8);
        vm.startPrank(bob);
        stp.slashRewards(alice);
        vm.stopPrank();

        mint(alice, 3e8);
        assertEq(stp.rewardBalanceOf(alice), 4500000);
    }
}
