// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RewardPoolTests is BaseTest {
    RewardPool internal pool;

    CurveParams internal params =
        CurveParams({id: 0, numPeriods: 6, periodSeconds: 2, startTimestamp: 0, minMultiplier: 0, formulaBase: 2});

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
        assertEq(pool.poolDetail().currencyAddress, address(0));
        assertEq(pool.poolDetail().balance, 0);
    }

    function testAdminMint() public {
        pool.adminMint(alice, 1e18);
        assertEq(pool.holderDetail(alice).numShares, 1e18);
        assertEq(pool.poolDetail().totalShares, 1e18);
    }

    function testYield() public {
        pool.adminMint(alice, 1e5);
        vm.expectEmit(true, true, false, true, address(pool));
        emit RewardLib.RewardsAllocated(1e18);
        pool.yieldRewards{value: 1e18}(1e18);
        assertEq(pool.poolDetail().balance, 1e18);
        (bool sent,) = address(pool).call{value: 1e18}("");
        assertEq(pool.poolDetail().balance, 2e18);
    }

    function testRewards() public {
        pool.adminMint(alice, 1e18);
        pool.yieldRewards{value: 1e18}(1e18);
        assertEq(pool.holderDetail(alice).rewardBalance, 1e18);
        pool.transferRewardsFor(alice);
        assertEq(pool.holderDetail(alice).rewardBalance, 0);
        assertEq(pool.poolDetail().balance, 0);
    }

    function testRewardBalanceOverTime() public {
        pool.adminMint(alice, 1e18);
        pool.yieldRewards{value: 1e18}(1e18);
        pool.transferRewardsFor(alice);
        assertEq(pool.holderDetail(alice).rewardBalance, 0);
        pool.yieldRewards{value: 1e17}(1e17);
        assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17, 100);
        pool.adminMint(bob, 1e18);
        assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17, 100);
        assertEq(pool.holderDetail(bob).rewardBalance, 0);
        pool.yieldRewards{value: 1e17}(1e17);
        assertApproxEqRel(pool.holderDetail(bob).rewardBalance, 1e17 / 2, 100);
        assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17 * 3 / 2, 100);
        pool.adminMint(bob, 1e18);
        assertApproxEqRel(pool.holderDetail(bob).rewardBalance, 1e17 / 2, 100);
        assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17 * 3 / 2, 100);
        pool.slash(bob);
        assertApproxEqRel(pool.holderDetail(bob).rewardBalance, 0, 100);
        assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17 * 2, 100);
        pool.transferRewardsFor(alice);
        assertEq(pool.holderDetail(alice).rewardBalance, 0);
    }

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

    //     function testSlashingNoRewards() public {
    //         CurveParams.bips = 0;

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
