// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/InitParams.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TierLib} from "src/libraries/TierLib.sol";

contract SubscriptionTokenV2TiersTest is BaseTest {
    function setUp() public {
        reinitStp();
    }

    function testValidTier() public prank(creator) {
        stp.createTier(2, tierParams);
    }

    function testInvalidTierId() public prank(creator) {
        vm.expectRevert(abi.encodeWithSelector(TierLib.InvalidTierId.selector));
        stp.createTier(3, tierParams);
        vm.expectRevert(abi.encodeWithSelector(TierLib.InvalidTierId.selector));
        stp.createTier(0, tierParams);
        vm.expectRevert(abi.encodeWithSelector(TierLib.InvalidTierId.selector));
        stp.createTier(1, tierParams);
    }

    function testInvalidUser() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));
        stp.createTier(2, tierParams);
    }
}
