// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/InitParams.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TierLib} from "src/libraries/TierLib.sol";

contract SubscriptionTokenV2TiersTest is BaseTest {
    function setUp() public {
        reinitStp();
    }

    function testValidTier() public prank(creator) {
        tierParams.id = 2;
        stp.createTier(tierParams);
    }

    function testInvalidTierId() public prank(creator) {
        tierParams.id = 3;
        vm.expectRevert(abi.encodeWithSelector(TierLib.InvalidTierId.selector));
        stp.createTier(tierParams);

        tierParams.id = 0;
        vm.expectRevert(abi.encodeWithSelector(TierLib.InvalidTierId.selector));
        stp.createTier(tierParams);

        tierParams.id = 1;
        vm.expectRevert(abi.encodeWithSelector(TierLib.InvalidTierId.selector));
        stp.createTier(tierParams);
    }

    function testInvalidUser() public {
        tierParams.id = 2;
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.createTier(tierParams);
    }
}
