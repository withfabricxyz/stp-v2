// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RecoveryTests is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
        stp = reinitStp();
        stp = reinitStp();
    }

    function testRecoverERC20Self() public erc20 prank(creator) {
        address addr = stp.contractDetail().currency;
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.recoverCurrency(addr, alice, 1e17);
    }

    function testRecoverERC20() public prank(creator) {
        TestERC20Token token = new TestERC20Token("FIAT", "FIAT", 18);
        token.transfer(address(stp), 1e17);
        stp.recoverCurrency(address(token), alice, 1e17);
        assertEq(token.balanceOf(alice), 1e17);
    }

    function testRecoverNative() public erc20 prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        stp.recoverCurrency(address(0), bob, 1e18);

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);

        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        stp.recoverCurrency(address(0), address(this), 1e18);

        assertEq(bob.balance, 0);
        stp.recoverCurrency(address(0), bob, 1e18);
        assertEq(bob.balance, 1e18);
    }
}
