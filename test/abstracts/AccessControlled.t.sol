// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";
import {AccessControlled} from "src/abstracts/AccessControlled.sol";

contract TestSubject is AccessControlled, Test {
    constructor(address account) {
        _setOwner(account);
    }

    function checkManager() external view {
        _checkRoles(2);
    }

    function checkOwnerOrManager() external view {
        _checkOwnerOrRoles(2);
    }

    function checkOwnerCall() external view {
        _checkOwner();
    }

    function test() public {}
}

contract AccessControlledTest is Test {
    address internal alice = 0xb4c79DAB8f259c7Aee6E5b2aa729821864227E81;

    TestSubject public subject;

    function setUp() public {
        subject = new TestSubject(address(this));
    }

    function testRoleSetting() public {
        vm.expectEmit(true, true, false, true, address(subject));
        emit AccessControlled.RoleChanged(alice, 4);
        subject.setRoles(alice, 4);
    }

    function testAdmin() public {
        subject.checkOwnerOrManager();
        subject.checkOwnerCall();

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        subject.checkManager();

        vm.expectEmit(true, true, false, true, address(subject));
        emit AccessControlled.OwnerProposed(alice);
        subject.setPendingOwner(alice);
        subject.setPendingOwner(address(0));
        subject.setPendingOwner(alice);

        assertEq(alice, subject.pendingOwner());

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        subject.acceptOwnership();

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(subject));
        emit AccessControlled.OwnerChanged(alice);
        subject.acceptOwnership();
        subject.checkOwnerCall();
        vm.stopPrank();

        assertEq(subject.owner(), alice);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        subject.checkOwnerCall();
    }

    function testRoles() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        subject.checkManager();
        vm.stopPrank();

        subject.setRoles(alice, 2);
        vm.startPrank(alice);
        subject.checkManager();
        vm.stopPrank();

        subject.setRoles(alice, 3);
        assertEq(subject.rolesOf(alice), 3);
        vm.startPrank(alice);
        subject.checkManager();
        vm.stopPrank();
    }

    function testChecks() public {}
}
