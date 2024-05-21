// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract FeesTest is BaseTest {
    function setUp() public {
        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);

        feeParams.protocolBps = 100;
        feeParams.clientBps = 400;
        feeParams.protocolRecipient = fees;
        feeParams.clientRecipient = fees;
        reinitStp();
    }

    function testTransfers() public {
        assertEq(100, stp.feeDetail().protocolBps);
        assertEq(fees, stp.feeDetail().protocolRecipient);

        uint256 expectedProtocolFee = (1e18 * 100) / 10_000;
        uint256 expectedClientFee = (1e18 * 400) / 10_000;
        uint256 preBalance = fees.balance;

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.FeeTransfer(fees, expectedClientFee);
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.FeeTransfer(fees, expectedProtocolFee);
        stp.mint{value: 1e18}(1e18);
        vm.stopPrank();

        assertEq(fees.balance, preBalance + expectedClientFee + expectedProtocolFee);
    }

    function testProtocolFeeUpdate() public {
        // this contract is the factory, so it can update the protocol fee
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.ProtocolFeeRecipientChange(charlie);
        stp.updateProtocolFeeRecipient(charlie);

        vm.startPrank(charlie);
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.updateProtocolFeeRecipient(charlie);
    }

    function testFeeCollectorRelinquish() public {
        stp.updateProtocolFeeRecipient(address(0));
        assertEq(stp.feeDetail().protocolRecipient, address(0));
        assertEq(stp.feeDetail().protocolBps, 0);
    }

    function testClientFeeUpdate() public {
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.ClientFeeRecipientChange(charlie);
        stp.updateClientFeeRecipient(charlie);

        vm.startPrank(charlie);
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.updateClientFeeRecipient(charlie);
    }

    function testClientCollectorRelinquish() public {
        stp.updateClientFeeRecipient(address(0));
        assertEq(stp.feeDetail().clientRecipient, address(0));
        assertEq(stp.feeDetail().clientBps, 0);
    }
}
