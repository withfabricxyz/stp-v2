// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams, Subscription} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {AllocationLib} from "src/libraries/AllocationLib.sol";
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

    function testTieredMint() public {}

    function testGatedMint() public {}

    function testPricedMint() public {}

    function testFeeMint() public {}

    function testMintTooLong() public {}

    function testCappedMint() public {}

    function testPausedMint() public {}

    // Mint Params
}
