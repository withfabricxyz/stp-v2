// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

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
        (address recipient, uint16 bps) = stp.feeSchedule();

        assertEq(bps, 500);
        assertEq(recipient, fees);

        uint256 expectedFee = (1e18 * 500) / 10000;
        uint256 balance = creator.balance;

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.FeeAllocated(expectedFee);
        stp.mint{value: 1e18}(1e18);
        vm.stopPrank();

        withdraw();

        assertEq(creator.balance, balance + (1e18 - expectedFee));
        assertEq(stp.feeBalance(), expectedFee);
    }

    function testFeeTransfer() public {
        mint(alice, 1e18);
        withdraw();

        uint256 expectedFee = (1e18 * 500) / 10000;
        uint256 balance = fees.balance;

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.FeeTransfer(address(this), fees, expectedFee);
        stp.transferFees();
        assertEq(fees.balance, balance + expectedFee);
        assertEq(stp.feeBalance(), 0);

        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.transferFees();
    }

    function testWithdrawWithFees() public {
        mint(alice, 1e18);
        mint(bob, 1e18);

        uint256 balance = creator.balance;
        uint256 feeBalance = fees.balance;
        uint256 expectedFee = (2e18 * 500) / 10000;

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.withdrawAndTransferFees();

        vm.startPrank(creator);
        stp.withdrawAndTransferFees();
        assertEq(creator.balance, balance + 2e18 - expectedFee);
        assertEq(fees.balance, feeBalance + expectedFee);
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
        mint(alice, 5e18);
        withdraw();

        assertEq(stp.creatorBalance(), 0);

        uint256 expectedFee = (5e18 * 500) / 10000;
        assertEq(stp.feeBalance(), expectedFee);

        vm.startPrank(fees);
        stp.updateFeeRecipient(address(0));
        vm.stopPrank();

        (address recipient, uint16 bps) = stp.feeSchedule();
        assertEq(recipient, address(0));
        assertEq(bps, 0);

        assertEq(stp.feeBalance(), 0);
        assertEq(stp.creatorBalance(), expectedFee);
    }

    function testRenounce() public {
        mint(alice, 1e18);
        withdraw();
        mint(alice, 1e17);

        uint256 balance = fees.balance;
        vm.startPrank(creator);
        stp.renounceOwnership();
        vm.stopPrank();

        assertGt(fees.balance, balance);
        assertEq(stp.feeBalance(), 0);
    }

    function testTransferAll() public {
        mint(alice, 1e18);
        mint(bob, 1e18);

        vm.startPrank(creator);
        stp.setTransferRecipient(creator);
        vm.stopPrank();

        uint256 balance = creator.balance;
        uint256 feeBalance = fees.balance;
        uint256 expectedFee = (2e18 * 500) / 10000;
        stp.transferAllBalances();
        assertEq(creator.balance, balance + 2e18 - expectedFee);
        assertEq(fees.balance, feeBalance + expectedFee);
    }
}
