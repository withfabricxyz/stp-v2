// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RewardPoolTests is BaseTest {
    RewardPool internal pool;

    RewardCurveParams internal params =
        RewardCurveParams({numPeriods: 6, periodSeconds: 2, startTimestamp: 0, minMultiplier: 0, formulaBase: 2});

    function reinitPool(address currency) internal returns (RewardPool pool) {
        pool = new RewardPool();
        vm.store(
            address(pool),
            bytes32(uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132)),
            bytes32(0)
        );
        // pool.initialize("Rewards", "rSUB", params, currency);
        pool.initialize(defaultPoolParams(), defaultCurveParams());
        pool.setRoles(address(this), 0xff); // allow admin mint
        return pool;
    }

    function setUp() public {
        pool = reinitPool(address(0));
    }

    function testConfig() public {
        assertEq(pool.name(), defaultPoolParams().name);
        assertEq(pool.symbol(), defaultPoolParams().symbol);
        assertEq(pool.currency(), address(0));
        assertEq(pool.balance(), 0);
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.rewardMultiplier(), 64);
    }

    function testAdminMint() public {
        pool.adminMint(alice, 1e18);
        assertEq(pool.balanceOf(alice), 1e18);
        assertEq(pool.totalSupply(), 1e18);
    }

    function testAllocation() public {
        pool.distributeRewards{value: 1e18}(1e18);
        assertEq(pool.balance(), 1e18);
        assertEq(address(pool).balance, 1e18);
        (bool sent,) = address(pool).call{value: 1e18}("");
        assertEq(pool.balance(), 2e18);
    }

    function testRewardBalance() public {
        pool.adminMint(alice, 1e18);
        assertEq(pool.rewardBalanceOf(alice), 0);
        pool.distributeRewards{value: 1e18}(1e18);
        assertEq(pool.rewardBalanceOf(alice), 1e18);
    }

    function testRewardBalanceOverTime() public {
        pool.adminMint(alice, 1e18);
        pool.distributeRewards{value: 1e18}(1e18);
        pool.transferRewardsFor(alice);
        assertEq(pool.rewardBalanceOf(alice), 0);
        pool.distributeRewards{value: 1e17}(1e17);
        assertEq(pool.rewardBalanceOf(alice), 1e17);

        // TODO
        // vm.startPrank(alice);
        // pool.unstake();
        // vm.stopPrank();
        // assertEq(pool.rewardBalanceOf(alice), 0);
    }

    // function testSingleHalving() public {
    //     RewardCurveParams.bips = 500;
    //     RewardCurveParams.numPeriods = 1;
    //     RewardCurveParams.periodSeconds = 10;
    //     reinitStp();
    //     assertEq(stp.rewardMultiplier(), 2);
    //     vm.warp(block.timestamp + 11);
    //     assertEq(stp.rewardMultiplier(), 1);
    //     vm.warp(block.timestamp + 21);
    //     assertEq(stp.rewardMultiplier(), 0);
    // }

    //     function testDecay() public {
    //         uint256 halvings = 6;
    //         for (uint256 i = 0; i <= halvings; i++) {
    //             vm.warp((stp.minPurchaseSeconds() * i) + 1);
    //             assertEq(stp.rewardMultiplier(), (2 ** (halvings - i)));
    //         }
    //         vm.warp((stp.minPurchaseSeconds() * 7) + 1);
    //         assertEq(stp.rewardMultiplier(), 0);
    //     }

    //     function testRewardPointPool() public prank(alice) {
    //         vm.expectEmit(true, true, false, true, address(stp));
    //         emit ISubscriptionTokenV2.RewardsAllocated(1e18 * 500 / 10_000);
    //         stp.mint{value: 1e18}(1e18);
    //         Subscription memory sub = stp.subscriptionOf(alice);
    //         assertEq(stp.rewardMultiplier(), 64);
    //         assertEq(sub.rewardPoints, 1e18 * 64);
    //         assertEq(stp.totalRewardPoints(), 1e18 * 64);

    //         // 2nd allocation
    //         stp.mint{value: 1e18}(1e18);
    //         Subscription memory sub2 = stp.subscriptionOf(alice);
    //         assertEq(sub2.rewardPoints, 2e18 * 64);
    //         assertEq(stp.totalRewardPoints(), 2e18 * 64);
    //     }

    //     function testDisabledWithdraw() public {
    //         stp = createETHSub(2592000, 0, 0);
    //         mint(alice, 1e18);
    //         withdraw();
    //         assertEq(0, stp.rewardBalanceOf(alice));
    //         vm.startPrank(alice);
    //         vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
    //         stp.transferRewardsFor(alice);
    //         vm.stopPrank();
    //     }

    //     function testRewardPointWithdraw() public {
    //         mint(alice, 1e18);
    //         uint256 preBalance = creator.balance;
    //         withdraw();
    //         assertEq(preBalance + 1e18 - ((1e18 * 500) / 10_000), creator.balance);
    //         vm.startPrank(alice);
    //         preBalance = alice.balance;
    //         assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(alice));
    //         vm.expectEmit(true, true, false, true, address(stp));
    //         emit ISubscriptionTokenV2.RewardWithdraw(alice, (1e18 * 500) / 10_000);
    //         stp.transferRewardsFor(alice);
    //         assertEq(preBalance + (1e18 * 500) / 10_000, alice.balance);
    //         assertEq(0, stp.rewardBalanceOf(alice));
    //         vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
    //         stp.transferRewardsFor(alice);
    //         vm.stopPrank();

    //         mint(bob, 1e18);
    //         withdraw();
    //         assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(bob));
    //         assertEq(0, stp.rewardBalanceOf(alice));

    //         mint(charlie, 1e18);
    //         withdraw();
    //         assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(bob));
    //         assertEq((1e18 * 500) / 10_000, stp.rewardBalanceOf(charlie));
    //         assertEq(0, stp.rewardBalanceOf(alice));
    //     }

    //     function testRewardPointWithdrawStepped() public {
    //         mint(alice, 1e18);
    //         vm.warp(31 days);
    //         mint(bob, 1e18);
    //         vm.warp(61 days);
    //         mint(charlie, 1e18);
    //         vm.warp(91 days);
    //         mint(doug, 1e18);

    //         withdraw();
    //         uint256 totalPool = (4e18 * 500) / 10_000;

    //         assertEq((totalPool * 64) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(alice));
    //         assertEq((totalPool * 32) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(bob));
    //         assertEq((totalPool * 16) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(charlie));
    //         assertEq((totalPool * 8) / (64 + 32 + 16 + 8), stp.rewardBalanceOf(doug));

    //         stp.transferRewardsFor(alice);
    //         assertEq(0, stp.rewardBalanceOf(alice));

    //         mint(doug, 1e18);
    //         withdraw();

    //         uint256 withdrawn = (totalPool * 64) / (64 + 32 + 16 + 8);
    //         totalPool = (5e18 * 500) / 10_000;
    //         assertEq((totalPool * 64) / (64 + 32 + 16 + 8 + 8) - withdrawn, stp.rewardBalanceOf(alice));

    //         stp.transferRewardsFor(alice);
    //     }

    //     function testWithdrawExpired() public {
    //         mint(alice, 2592000 * 2);
    //         vm.warp(60 days);
    //         withdraw();
    //         vm.startPrank(alice);
    //         vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.SubscriptionNotActive.selector));
    //         stp.transferRewardsFor(alice);
    //         vm.stopPrank();
    //     }

    //     function testSlashingNoRewards() public {
    //         RewardCurveParams.bips = 0;

    //         reinitStp();

    //         mint(alice, 2592000 * 2);
    //         mint(bob, 1e8);

    //         vm.warp(2592000 * 3);
    //         vm.startPrank(bob);
    //         vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardsDisabled.selector));
    //         stp.slashRewards(alice);
    //         vm.stopPrank();
    //     }

    //     function testSlashing() public {
    //         mint(alice, 2592000 * 2);
    //         mint(bob, 1e8);

    //         uint256 beforePoints = stp.totalRewardPoints();
    //         Subscription memory sub = stp.subscriptionOf(alice);

    //         vm.warp(2592000 * 3);
    //         vm.startPrank(bob);
    //         vm.expectEmit(true, true, false, true, address(stp));
    //         emit ISubscriptionTokenV2.RewardPointsSlashed(alice, bob, sub.rewardPoints);
    //         stp.slashRewards(alice);
    //         vm.stopPrank();

    //         uint256 afterPoints = stp.totalRewardPoints();
    //         Subscription memory sub2 = stp.subscriptionOf(alice);

    //         assertEq(0, sub2.rewardPoints);
    //         assertEq(afterPoints, beforePoints - sub.rewardPoints);
    //     }

    //     function testSlashingWithdraws() public {
    //         mint(alice, 2592000 * 2);
    //         vm.warp((stp.minPurchaseSeconds() * 3) + 1);
    //         mint(bob, 1e8);

    //         // Allocate rewards
    //         withdraw();
    //         vm.startPrank(bob);
    //         stp.transferRewardsFor(bob);
    //         assertEq(stp.rewardBalanceOf(bob), 0);
    //         stp.slashRewards(alice);
    //         assertEq(stp.rewardBalanceOf(bob), stp.rewardPoolBalance());
    //         stp.transferRewardsFor(bob);
    //         vm.stopPrank();
    //     }

    //     function testDoubleSlash() public {
    //         mint(alice, 2592000 * 2);
    //         vm.warp((stp.minPurchaseSeconds() * 3) + 1);
    //         mint(bob, 1e8);
    //         withdraw();
    //         vm.startPrank(bob);
    //         stp.slashRewards(alice);
    //         vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardSlashingNotPossible.selector));
    //         stp.slashRewards(alice);
    //         vm.stopPrank();
    //     }

    //     function testNoPointPool() public {
    //         vm.warp(365 days);
    //         // first mint is after reward points go to 0
    //         mint(alice, 1e18);
    //         withdraw();
    //         assertEq(0, stp.rewardPoolBalance());
    //     }

    //     // TODO
    //     // function testRewardPoolToCreator() public {
    //     //     mint(alice, 1e18);
    //     //     withdraw();
    //     //     assertEq(5e16, stp.rewardPoolBalance());
    //     //     assertEq(5e16, stp.rewardBalanceOf(alice));

    //     //     (,,, uint256 expires) = stp.subscriptionOf(alice);
    //     //     vm.warp(expires * 5);
    //     //     mint(bob, 1e18);
    //     //     vm.startPrank(bob);
    //     //     stp.slashRewards(alice);
    //     //     vm.stopPrank();

    //     //     assertEq(0, stp.rewardPoolBalance());
    //     //     // total points -> 0, so remaining rewards go back to creator
    //     //     assertEq(1e18 + 5e16, stp.creatorBalance());
    //     // }

    //     function testSlashPostWithdraw() public {
    //         mint(alice, 3e8);
    //         mint(bob, 2e8);
    //         mint(charlie, 1e8);

    //         uint256 aliceBalance = stp.rewardBalanceOf(alice);
    //         assertEq(aliceBalance, 15000000);

    //         // withdraw rewards for alice
    //         vm.startPrank(charlie);
    //         stp.transferRewardsFor(charlie);
    //         vm.stopPrank();

    //         // Go past expiration
    //         // TODO
    //         // (,,, uint256 expires) = stp.subscriptionOf(charlie);
    //         // vm.warp(expires + expires + 1);

    //         // // slash charlie
    //         // vm.startPrank(alice);
    //         // stp.slashRewards(charlie);
    //         // vm.stopPrank();

    //         // assertEq(stp.rewardBalanceOf(alice), aliceBalance);
    //         // assertEq(stp.rewardBalanceOf(charlie), 0);
    //     }

    //     function testSlashPostWithdrawDistanceFuture() public {
    //         mint(alice, 3e8);
    //         mint(bob, 2e8);
    //         mint(charlie, 1e8);

    //         uint256 aliceBalance = stp.rewardBalanceOf(alice);
    //         assertEq(aliceBalance, 15000000);

    //         // withdraw rewards for charlie
    //         vm.startPrank(charlie);
    //         stp.transferRewardsFor(charlie);
    //         vm.stopPrank();

    //         // Go far past expiration
    //         // TODO
    //         Subscription memory sub = stp.subscriptionOf(charlie);
    //         // vm.warp(expires + expires + 1e6);

    //         // // slash charlie
    //         // vm.startPrank(alice);
    //         // stp.slashRewards(charlie);
    //         // vm.stopPrank();

    //         // assertEq(stp.rewardBalanceOf(alice), aliceBalance);

    //         // Subscription memory sub = stp.subscriptionOf(charlie);
    //         // assertEq(sub.rewardPoints, 0);
    //     }
}
