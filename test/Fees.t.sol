// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {AccessControlled} from "src/abstracts/AccessControlled.sol";

contract FeesTest is BaseTest {
    function setUp() public {
        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);

        feeParams.bips = 500;
        feeParams.collector = fees;
        reinitStp();
    }

    function testPool() public {
        (address recipient, uint16 bps) = stp.feeParams();

        assertEq(bps, 500);
        assertEq(recipient, fees);

        uint256 expectedFee = (1e18 * 500) / 10000;
        uint256 balance = creator.balance;

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.FeeTransfer(recipient, expectedFee);
        stp.mint{value: 1e18}(1e18);
        vm.stopPrank();
    }

    function testFeeCollectorUpdate() public {
        vm.startPrank(fees);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.FeeCollectorChange(charlie);
        stp.updateFeeRecipient(charlie);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.Unauthorized.selector));
        stp.updateFeeRecipient(charlie);
        vm.stopPrank();
    }

    function testFeeCollectorRelinquish() public {
        vm.startPrank(fees);
        stp.updateFeeRecipient(address(0));
        vm.stopPrank();

        (address recipient, uint16 bps) = stp.feeParams();
        assertEq(recipient, address(0));
        assertEq(bps, 0);
    }
}
