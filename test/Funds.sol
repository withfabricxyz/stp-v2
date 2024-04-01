// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract FundsTest is BaseTest {
    function setUp() public {
        stp = reinitStp();
        deal(creator, 5 ether);
        deal(alice, 5 ether);
        deal(charlie, 5 ether);
    }

    function testTopUp() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TopUp(1 ether);
        stp.topUp{value: 1 ether}(1 ether);
    }

    // TODO
    // function testDistribute() public prank(creator) {
    //     vm.expectEmit(true, true, false, true, address(stp));
    //     emit ISubscriptionTokenV2.TopUp(1 ether);
    //     stp.topUp{value: 1 ether}(1 ether);
    // }

    // function testRewardDistribution() public {
    //     mint(alice, 1e8);
    //     mint(charlie, 1e8);

    //     uint256 b1 = stp.rewardBalanceOf(alice);

    //     vm.startPrank(creator);
    //     stp.distributeRewards{value: 1e18}(1e18);
    //     vm.stopPrank();

    //     uint256 b2 = stp.rewardBalanceOf(alice);
    //     assertEq(b1 + 0.5 ether, b2);
    // }

    // function testDistributeNoRewards() public prank(creator) {
    //     vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardsDisabled.selector));
    //     stp.distributeRewards{value: 1e18}(1e18);
    // }
}
