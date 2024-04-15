// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RewardPoolTests is BaseTest {
// RewardPool internal pool;

// CurveParams internal params =
//     CurveParams({id: 0, numPeriods: 6, periodSeconds: 2, startTimestamp: 0, minMultiplier: 0, formulaBase: 2});

// function reinitPool(address currency) internal returns (RewardPool pool) {
//     pool = new RewardPool();
//     vm.store(
//         address(pool),
//         bytes32(uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132)),
//         bytes32(0)
//     );
//     pool.initialize(defaultPoolParams(), defaultCurveParams());
//     pool.setRoles(address(this), 0xff); // allow admin mint
//     return pool;
// }

// function setUp() public {
//     pool = reinitPool(address(0));
// }

// function testConfig() public {
//     assertEq(pool.poolDetail().currencyAddress, address(0));
//     assertEq(pool.poolDetail().balance, 0);
// }

// function testAdminMint() public {
//     pool.adminMint(alice, 1e18, 0);
//     assertEq(pool.holderDetail(alice).numShares, 1e18);
//     assertEq(pool.poolDetail().totalShares, 1e18);
// }

// function testYield() public {
//     pool.adminMint(alice, 1e5, 0);
//     vm.expectEmit(true, true, false, true, address(pool));
//     emit RewardLib.RewardsAllocated(1e18);
//     pool.yieldRewards{value: 1e18}(1e18);
//     assertEq(pool.poolDetail().balance, 1e18);
//     (bool sent,) = address(pool).call{value: 1e18}("");
//     assertEq(pool.poolDetail().balance, 2e18);
// }

// function testRewards() public {
//     pool.adminMint(alice, 1e18, 0);
//     pool.yieldRewards{value: 1e18}(1e18);
//     assertEq(pool.holderDetail(alice).rewardBalance, 1e18);
//     pool.transferRewardsFor(alice);
//     assertEq(pool.holderDetail(alice).rewardBalance, 0);
//     assertEq(pool.poolDetail().balance, 0);
// }

// function testPoolDetail() public {
//     pool.adminMint(alice, 1e18, 0);
// }

// function testHolderDetail() public {
//     pool.adminMint(alice, 1e18, 10_000);
//     assertEq(pool.holderDetail(alice).numShares, 1e18);
//     assertEq(pool.holderDetail(alice).rewardBalance, 0);
//     assertEq(pool.holderDetail(alice).rewardsWithdrawn, 0);
// }

// // Ensure the reward balance is accurate as shares and rewards are issued and burned
// function testRewardBalanceOverTime() public {
//     pool.adminMint(alice, 1e18, 0);
//     pool.yieldRewards{value: 1e18}(1e18);
//     pool.transferRewardsFor(alice);
//     assertEq(pool.holderDetail(alice).rewardBalance, 0);
//     pool.yieldRewards{value: 1e17}(1e17);
//     assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17, 100);
//     pool.adminMint(bob, 1e18, 0);
//     assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17, 100);
//     assertEq(pool.holderDetail(bob).rewardBalance, 0);
//     pool.yieldRewards{value: 1e17}(1e17);
//     assertApproxEqRel(pool.holderDetail(bob).rewardBalance, 1e17 / 2, 100);
//     assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17 * 3 / 2, 100);
//     pool.adminMint(bob, 1e18, 0);
//     assertApproxEqRel(pool.holderDetail(bob).rewardBalance, 1e17 / 2, 100);
//     assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17 * 3 / 2, 100);
//     pool.slash(bob);
//     assertApproxEqRel(pool.holderDetail(bob).rewardBalance, 0, 100);
//     assertApproxEqRel(pool.holderDetail(alice).rewardBalance, 1e17 * 2, 100);
//     pool.transferRewardsFor(alice);
//     assertEq(pool.holderDetail(alice).rewardBalance, 0);
// }
}
