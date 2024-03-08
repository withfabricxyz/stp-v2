// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BaseTest} from "./TestHelpers.t.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SubscriptionTokenV2TiersTest is BaseTest {
    address internal agent = 0xb4c79DAb8F259C7aEe6E5B2aA729821864227e7C;

    function setUp() public {
        reinitStp();

        vm.startPrank(creator);
        stp.grantRole(keccak256("MANAGER_ROLE"), agent);
        vm.stopPrank();
    }

    function testAdminRole() public {
        assertEq(stp.defaultAdmin(), address(creator));
        vm.warp(block.timestamp + 1000 days);
        assertEq(stp.defaultAdmin(), address(creator));
    }

    function testGrantTime() public {
        vm.startPrank(creator);
        // grant time
        vm.stopPrank();
        vm.startPrank(agent);
        // grant time
        vm.stopPrank();
    }

    function testRevokeGrantedTime() public {
        vm.startPrank(creator);
        // revoke grants
        vm.stopPrank();
        vm.startPrank(agent);
        // revoke grants
        vm.stopPrank();
    }

    function testMintRefund() public {
        vm.startPrank(creator);
        // refund time
        vm.stopPrank();
        vm.startPrank(agent);
        // refund time
        vm.stopPrank();
    }
}
