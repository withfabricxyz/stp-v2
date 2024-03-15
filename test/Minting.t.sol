// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
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
    }

    // Mint Params
}
