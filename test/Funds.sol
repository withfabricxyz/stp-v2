// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract FundsTest is BaseTest {
    function setUp() public {
        stp = reinitStp();
        deal(creator, 5 ether);
        deal(alice, 5 ether);
        deal(charlie, 5 ether);
    }

    function testTopUp() public prank(creator) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.TopUp(1 ether);
        stp.topUp{value: 1 ether}(1 ether);
    }

    function testTransferRecipient() public {
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.TransferRecipientChange(alice);
        stp.setTransferRecipient(alice);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.setTransferRecipient(alice);

        mint(alice, 1 ether);
        stp.transferFunds(alice, stp.contractDetail().creatorBalance);
    }
}
