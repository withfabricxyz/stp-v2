// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams, Subscription} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";
import {RewardLib} from "src/libraries/RewardLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";

contract MintingTest is BaseTest {
    function setUp() public {
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testSimpleMint() public {
        assertEq(stp.balanceOf(alice), 0);
        mint(alice, 1e18);
        assertTrue(stp.balanceOf(alice) > 0);
        Subscription memory sub = stp.subscriptionDetail(alice);
        assertEq(sub.tokenId, 1);
        assertEq(sub.tierId, 1);
        assertEq(sub.secondsPurchased, 5e17);
        assertEq(sub.secondsGranted, 0);
        assertEq(sub.rewardPoints, stp.rewardMultiplier() * 1e18);
        assertEq(sub.rewardsWithdrawn, 0);
        // TODO: Expired At
    }

    function testGlobalSupplyCap() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.GlobalSupplyLimitExceeded.selector));
        stp.setGlobalSupplyCap(1);

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.GlobalSupplyCapChange(2);
        stp.setGlobalSupplyCap(2);
        vm.stopPrank();

        vm.startPrank(charlie);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.GlobalSupplyLimitExceeded.selector));
        stp.mint{value: 1e18}(1e18);
    }

    function testTierJoinChecks() public {}

    function testNewMintChecks() public {}

    function testRenewalChecks() public prank(creator) {
        stp.pauseTier(1);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierRenewalsPaused.selector));
        stp.mintFor{value: 1e18}(alice, 1e18);
    }

    // Mint Params
}
