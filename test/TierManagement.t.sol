// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract TierManagementTest is BaseTest {
    function setUp() public {
        reinitStp();
        deal(alice, 1e19);
        deal(bob, 1e19);
    }

    function testUpdate() public prank(creator) {
        stp.updateTier(1, tierParams);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierNotFound.selector, 5));
        stp.updateTier(5, tierParams);
    }

    function testTierPausing() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierPaused(1);
        tierParams.paused = true;
        stp.updateTier(1, tierParams);

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierUnpaused(1);
        tierParams.paused = false;
        stp.updateTier(1, tierParams);
    }

    function testTierPriceUpdate() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierPriceChange(1, 100);
        tierParams.pricePerPeriod = 100;
        stp.updateTier(1, tierParams);
    }

    function testTierUpdateSupplyCap() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TierSupplyCapChange(1, 5);
        tierParams.maxSupply = 5;
        stp.updateTier(1, tierParams);
    }

    function testInvalidTierCap() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidSupplyCap.selector));
        tierParams.maxSupply = 1;
        stp.updateTier(1, tierParams);
        vm.stopPrank();
    }

    function testAccessControl() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.updateTier(1, tierParams);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.createTier(tierParams);
    }
}
