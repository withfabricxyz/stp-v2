// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TierLib} from "src/libraries/TierLib.sol";

contract TierManagementTest is BaseTest {
    function setUp() public {
        reinitStp();
    }

    function testValidTier() public prank(creator) {
        tierParams.id = 2;
        stp.createTier(tierParams);
    }

    function testTierInvalidId() public prank(creator) {
        tierParams.id = 3;
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidId.selector));
        stp.createTier(tierParams);

        tierParams.id = 0;
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidId.selector));
        stp.createTier(tierParams);

        tierParams.id = 1;
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidId.selector));
        stp.createTier(tierParams);

        vm.expectRevert(abi.encodeWithSelector(TierLib.TierNotFound.selector, 5));
        stp.pauseTier(5);
    }

    function testTierPausing() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit TierLib.TierPaused(1);
        stp.pauseTier(1);

        vm.expectEmit(true, true, false, true, address(stp));
        emit TierLib.TierUnpaused(1);
        stp.unpauseTier(1);
    }

    function testTierPriceUpdate() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit TierLib.TierPriceChange(1, 4, 100);
        stp.setTierPrice(1, 100);
    }

    function testTierUpdateSupplyCap() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit TierLib.TierSupplyCapChange(1, 5);
        stp.setTierSupplyCap(1, 5);
    }

    function testAccessControl() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.setTierPrice(1, 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, this, keccak256("MANAGER_ROLE")
            )
        );
        stp.pauseTier(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, this, keccak256("MANAGER_ROLE")
            )
        );
        stp.unpauseTier(1);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.setTierSupplyCap(1, 5);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.createTier(tierParams);
    }
}