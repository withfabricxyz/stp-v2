// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract TierManagementTest is BaseTest {
    function setUp() public {
        reinitStp();
        deal(alice, 1e19);
        deal(bob, 1e19);
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
        emit ISubscriptionTokenV2.TierPaused(1);
        stp.pauseTier(1);

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierUnpaused(1);
        stp.unpauseTier(1);
    }

    function testTierPriceUpdate() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierPriceChange(1, 100);
        stp.setTierPrice(1, 100);
    }

    function testTierUpdateSupplyCap() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierSupplyCapChange(1, 5);
        stp.setTierSupplyCap(1, 5);
    }

    function testInvalidTierCap() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidSupplyCap.selector));
        stp.setTierSupplyCap(1, 1);
        vm.stopPrank();
    }

    function testAccessControl() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.setTierPrice(1, 100);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.pauseTier(1);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.unpauseTier(1);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.setTierSupplyCap(1, 5);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.createTier(tierParams);
    }
}
