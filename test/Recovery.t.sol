// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {CurrencyLib} from "src/libraries/CurrencyLib.sol";

contract RecoveryTests is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
        poolParams.numPeriods = 0;
        stp = reinitStp();
        stp = reinitStp();
    }

    function testRecoverERC20Self() public erc20 prank(creator) {
        address addr = stp.erc20Address();
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidRecovery.selector));
        stp.recoverCurrency(addr, alice, 1e17);
    }

    function testRecoverERC20() public prank(creator) {
        TestERC20Token token = new TestERC20Token("FIAT", "FIAT", 18);
        token.transfer(address(stp), 1e17);
        stp.recoverCurrency(address(token), alice, 1e17);
        assertEq(token.balanceOf(alice), 1e17);
    }

    // TODO
    function testRecoverNative() public erc20 prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        // vm.expectRevert(abi.encodeWithSelector(CurrencyLib.NativeTransferFailed.selector));
        // stp.recoverCurrency(address(0), bob, 1e18);

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);

        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.NativeTransferFailed.selector));
        stp.recoverCurrency(address(0), address(this), 1e18);

        stp.recoverCurrency(address(0), bob, 1e18);
        assertEq(bob.balance, 1e19 + 1e18);
    }
}
