// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";

contract RecoveryTests is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
        rewardParams.numPeriods = 0;
        stp = reinitStp();
        stp = reinitStp();
    }

    function testReconcile() public erc20 prank(creator) {
        // No-op
        stp.reconcileBalance();

        token().transfer(address(stp), 1e17);
        stp.reconcileBalance();
        assertEq(stp.creatorBalance(), 1e17);
    }

    function testRecoverERC20Self() public erc20 prank(creator) {
        address addr = stp.erc20Address();
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidRecovery.selector));
        stp.recoverERC20(addr, alice, 1e17);
    }

    function testRecoverERC20() public prank(creator) {
        TestERC20Token token = new TestERC20Token("FIAT", "FIAT", 18);
        token.transfer(address(stp), 1e17);
        stp.recoverERC20(address(token), alice, 1e17);
        assertEq(token.balanceOf(alice), 1e17);
    }

    function testReconcileNative() public prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        // no op
        stp.reconcileBalance();

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);
        assertEq(stp.creatorBalance(), 0);
        stp.reconcileBalance();
        assertEq(stp.creatorBalance(), 1e18);
    }

    function testRecoverNative() public erc20 prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidRecovery.selector));
        stp.recoverNativeTokens(bob);

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.TransferFailed.selector));
        stp.recoverNativeTokens(address(this));

        stp.recoverNativeTokens(bob);
        assertEq(stp.creatorBalance(), 0);
        assertEq(bob.balance, 1e19 + 1e18);
    }
}


