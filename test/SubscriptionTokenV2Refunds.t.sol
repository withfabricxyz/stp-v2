// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/InitParams.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AllocationLib} from "src/libraries/AllocationLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";

contract SubscriptionTokenV2RefundsTest is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
        rewardParams.numPeriods = 0;
        stp = reinitStp();

        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);
    }

    function testRefund() public {
        mint(alice, 1e18);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Refund(alice, tokenId, 1e18, 1e18 / 2);
        (creator, 2e18);
        stp.refund(0, list(alice));
        assertEq(address(stp).balance, 0);

        address[] memory subscribers = new address[](0);
        vm.expectRevert("No accounts to refund");
        stp.refund(0, subscribers);

        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, this, keccak256("MANAGER_ROLE")
            )
        );
        stp.refund(0, list(alice));
    }

    function testPartialRefund() public {
        mint(alice, 1e18);
        vm.warp(block.timestamp + 2.5e17);
        assertEq(5e17 / 2, stp.refundableBalanceOf(alice));
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Refund(alice, 1, 5e17, 5e17 / 2);
        stp.refund(0, list(alice));
        vm.stopPrank();
    }

    function testRefundNoPurchase() public {
        mint(alice, 1e18);
        uint256 balance = bob.balance;
        vm.startPrank(creator);
        stp.refund(0, list(bob));
        vm.stopPrank();
        assertEq(balance, bob.balance);
    }

    function testInvalidRefund() public {
        mint(alice, 1e18);
        vm.startPrank(creator);
        vm.expectRevert("Unexpected value transfer");
        stp.refund{value: 1}(0, list(alice));
        vm.stopPrank();
    }

    function testRefundCalc() public {
        mint(alice, 1e18);
        assertEq(1e18, stp.refundableTokenBalanceOfAll(list(alice, bob)));
        mint(bob, 1e18);
        assertEq(2e18, stp.refundableTokenBalanceOfAll(list(alice, bob)));
    }

    function testRefundDecay() public prank(alice) {
        stp.mint{value: 1e18}(1e18);
        vm.warp(block.timestamp + 25e16);
        assertEq(stp.balanceOf(alice), 5e17 / 2);
        assertEq(stp.refundableBalanceOf(alice), 5e17 / 2);
    }

    function testRefundNoBalance() public {
        mint(alice, 1e18);
        withdraw();
        assertFalse(stp.canRefund(list(alice)));
        vm.startPrank(creator);
        vm.expectRevert("Insufficient balance for refund");
        stp.refund(0, list(alice));

        // Send eth to contract while refunding
        vm.expectEmit(true, true, false, true, address(stp));
        emit RefundTopUp(2e18);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Refund(alice, 1, 1e18, 1e18 / 2);
        stp.refund{value: 2e18}(2e18, list(alice));
        assertEq(1e18, address(stp).balance);
        assertEq(1e18, stp.creatorBalance());
        vm.stopPrank();
    }

    /// ERC20

    function testRefundERC20() public erc20 {
        mint(alice, 1e18);
        uint256 beforeBalance = token().balanceOf(alice);
        vm.startPrank(creator);
        stp.refund(0, list(alice));
        vm.stopPrank();
        assertEq(beforeBalance + 1e18, token().balanceOf(alice));
    }

    function testRefundERC20AfterWithdraw() public erc20 {
        mint(alice, 1e18);
        vm.startPrank(creator);
        stp.withdraw();
        vm.expectRevert("Insufficient balance for refund");
        stp.refund(0, list(alice));
        vm.stopPrank();
    }
}
