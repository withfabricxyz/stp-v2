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

contract SubscriptionTokenV2Test is BaseTest {
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

    function testVersion() public {
        assertEq(2, stp.stpVersion());
    }

    function testMint() public prank(alice) {
        vm.expectEmit(true, true, false, true, address(stp));
        emit Purchase(alice, 1, 1e18, 1e18 / 2, 0, block.timestamp + (1e18 / 2));
        stp.mint{value: 1e18}(1e18);
        assertEq(address(stp).balance, 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
        (uint256 tokenId, uint256 numSeconds, uint256 points, uint256 expires) = stp.subscriptionOf(alice);
        assertEq(stp.ownerOf(tokenId), alice);
        assertEq(numSeconds, 1e18 / 2);
        assertEq(points, 0);
        assertEq(expires, block.timestamp + (1e18 / 2));
        assertEq(stp.tokenURI(1), "turi");
    }

    function testMintInvalid() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(AllocationLib.PurchaseAmountMustMatchValueSent.selector, 1e18, 1e17));
        stp.mint{value: 1e17}(1e18);
    }

    function testMintViaFallback() public prank(alice) {
        (bool sent,) = address(stp).call{value: 1e18}("");
        assertTrue(sent);
    }

    function testMintViaFallbackERC20() public erc20 prank(alice) {
        vm.expectRevert("Native tokens not accepted for ERC20 subscriptions");
        (, bytes memory data) = address(stp).call{value: 1e18}("");
        assertTrue(data.length > 0);
    }

    function testMintFor() public prank(alice) {
        vm.expectRevert("Account cannot be 0x0");
        stp.mintFor{value: 1e18}(address(0), 1e18);

        vm.expectEmit(true, true, false, true, address(stp));
        emit Purchase(bob, 1, 1e18, 1e18 / 2, 0, block.timestamp + (1e18 / 2));
        stp.mintFor{value: 1e18}(bob, 1e18);
        assertEq(address(stp).balance, 1e18);
        assertEq(stp.balanceOf(bob), 5e17);
        assertEq(stp.balanceOf(alice), 0);
        (uint256 tokenId,,,) = stp.subscriptionOf(bob);
        assertEq(stp.ownerOf(tokenId), bob);
    }

    function testMintForErc20() public erc20 prank(alice) {
        token().approve(address(stp), 1e18);
        stp.mintFor(bob, 1e18);
        assertEq(token().balanceOf(address(stp)), 1e18);
        assertEq(stp.balanceOf(bob), 5e17);
        assertEq(stp.balanceOf(alice), 0);
        (uint256 tokenId,,,) = stp.subscriptionOf(bob);
        assertEq(stp.ownerOf(tokenId), bob);
    }

    function testNonSub() public {
        assertEq(stp.balanceOf(alice), 0);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        stp.ownerOf(tokenId);
    }

    function testMintExpire() public prank(alice) {
        uint256 time = block.timestamp;
        stp.mint{value: 1e18}(1e18);
        vm.warp(block.timestamp + 6e17);
        assertEq(stp.balanceOf(alice), 0);
        (uint256 tokenId,,, uint256 expires) = stp.subscriptionOf(alice);
        assertEq(expires, time + 1e18 / 2);
        assertEq(stp.ownerOf(tokenId), alice);
    }

    function testMintSpaced() public {
        mint(alice, 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
        vm.warp(block.timestamp + 1e18);
        assertEq(stp.balanceOf(alice), 0);
        mint(alice, 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
    }

    function testCreatorEarnings() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        mint(charlie, 1e18);
        assertEq(stp.creatorBalance(), 3e18);
    }

    function testWithdraw() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        vm.startPrank(creator);
        assertEq(stp.creatorBalance(), 2e18);

        vm.expectEmit(true, true, false, true, address(stp));
        emit Withdraw(creator, 2e18);
        stp.withdraw();
        assertEq(stp.creatorBalance(), 0);
        assertEq(stp.totalCreatorEarnings(), 2e18);

        vm.expectRevert("No Balance");
        stp.withdraw();
        vm.stopPrank();

        assertEq(address(stp).balance, 0);
    }

    function testTransferEarnings() public {
        uint256 aliceBalance = alice.balance;
        mint(alice, 1e18);
        address invalid = address(this);
        vm.startPrank(creator);
        vm.expectRevert("Account cannot be 0x0");
        stp.withdrawTo(address(0));

        vm.expectRevert(abi.encodeWithSelector(AllocationLib.FailedToTransferEther.selector, invalid, 1e18));
        stp.withdrawTo(invalid);
        stp.withdrawTo(alice);
        vm.stopPrank();
        assertEq(aliceBalance, alice.balance);
    }

    function testPausing() public {
        vm.startPrank(creator);
        stp.pause();
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        stp.mint{value: 1e17}(1e17);
        vm.stopPrank();

        vm.startPrank(creator);
        stp.unpause();
        vm.stopPrank();

        mint(alice, 1e17);
    }

    /// ERC20

    function testERC20Mint() public erc20 prank(alice) {
        assert(stp.erc20Address() != address(0));
        assertEq(token().balanceOf(alice), 1e20);
        token().approve(address(stp), 1e18);
        stp.mint(1e18);
        assertEq(token().balanceOf(address(stp)), 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        assertEq(stp.ownerOf(tokenId), alice);
    }

    function testMintInvalidERC20() public erc20 prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(AllocationLib.NativeTokensNotAcceptedForERC20Subscriptions.selector));
        stp.mint{value: 1e17}(1e18);
        vm.expectRevert(
            abi.encodeWithSelector(AllocationLib.InsufficientBalanceOrAllowance.selector, token().balanceOf(alice), 0)
        );
        stp.mint(1e18);
    }

    function testERC20FeeTakingToken() public {
        TestFeeToken _token = new TestFeeToken("FIAT", "FIAT", 1e21);
        _token.transfer(alice, 1e20);
        initParams.erc20TokenAddr = address(_token);
        reinitStp();
        vm.startPrank(alice);
        _token.approve(address(stp), 1e18);
        stp.mint(1e18);
        assertEq(stp.balanceOf(alice), 1e18 / 2 / 2);
        vm.stopPrank();
    }

    function testWithdrawERC20() public erc20 {
        mint(alice, 1e18);
        mint(bob, 1e18);

        uint256 beforeBalance = token().balanceOf(creator);
        vm.startPrank(creator);
        assertEq(stp.creatorBalance(), 2e18);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Withdraw(creator, 2e18);
        stp.withdraw();
        assertEq(stp.creatorBalance(), 0);
        assertEq(stp.totalCreatorEarnings(), 2e18);

        vm.expectRevert("No Balance");
        stp.withdraw();
        vm.stopPrank();

        assertEq(beforeBalance + 2e18, token().balanceOf(creator));
    }

    function testTransfer() public {
        mint(alice, 1e18);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        vm.startPrank(alice);
        stp.approve(bob, tokenId);
        vm.expectEmit(true, true, false, true, address(stp));
        emit Transfer(alice, bob, tokenId);
        stp.transferFrom(alice, bob, tokenId);
        vm.stopPrank();
        assertEq(stp.ownerOf(tokenId), bob);
    }

    function testTransferToExistingHolder() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        (uint256 tokenId,,,) = stp.subscriptionOf(alice);
        vm.startPrank(alice);
        stp.approve(bob, tokenId);
        vm.expectRevert("Cannot transfer to existing subscribers");
        stp.transferFrom(alice, bob, tokenId);
    }

    function testUpdateMetadata() public {
        mint(alice, 1e18);

        vm.startPrank(creator);
        stp.updateMetadata("x", "y/");
        assertEq(stp.contractURI(), "x");
        assertEq(stp.tokenURI(1), "y/1");

        stp.updateMetadata("x", "z");
        assertEq(stp.tokenURI(1), "z");

        vm.expectRevert("Contract URI cannot be empty");
        stp.updateMetadata("", "z");

        vm.expectRevert("Token URI cannot be empty");
        stp.updateMetadata("be", "");
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, this, 0x00));
        stp.updateMetadata("x", "z");
    }

    function testRenounce() public {
        mint(alice, 1e18);
        withdraw();
        mint(alice, 1e17);

        vm.startPrank(creator);
        stp.renounceOwnership();
        vm.stopPrank();
        assertEq(stp.creatorBalance(), 0);
    }

    function testTransferAll() public {
        mint(alice, 1e18);
        mint(bob, 1e18);

        uint256 balance = charlie.balance;
        vm.expectRevert("Transfer recipient not set");
        stp.transferAllBalances();

        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit TransferRecipientChange(charlie);
        stp.setTransferRecipient(charlie);
        vm.stopPrank();

        assertEq(charlie, stp.transferRecipient());

        stp.transferAllBalances();

        assertEq(charlie.balance, balance + 2e18);
    }

    function testReconcile() public erc20 prank(creator) {
        // No-op
        stp.reconcileERC20Balance();

        token().transfer(address(stp), 1e17);
        stp.reconcileERC20Balance();
        assertEq(stp.creatorBalance(), 1e17);
    }

    function testRecoverERC20Self() public erc20 prank(creator) {
        address addr = stp.erc20Address();
        vm.expectRevert("Cannot recover subscription token");
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
        stp.reconcileNativeBalance();

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);
        assertEq(stp.creatorBalance(), 0);
        stp.reconcileNativeBalance();
        assertEq(stp.creatorBalance(), 1e18);

        vm.expectRevert("Not supported, use reconcileNativeBalance");
        stp.recoverNativeTokens(bob);
    }

    function testRecoverNative() public erc20 prank(creator) {
        SelfDestruct attack = new SelfDestruct();

        vm.expectRevert("No balance to recover");
        stp.recoverNativeTokens(bob);

        deal(address(attack), 1e18);
        attack.destroy(address(stp));

        assertEq(address(stp).balance, 1e18);

        vm.expectRevert("Failed to transfer Ether");
        stp.recoverNativeTokens(address(this));

        stp.recoverNativeTokens(bob);
        assertEq(stp.creatorBalance(), 0);
        assertEq(bob.balance, 1e19 + 1e18);
    }

    /// Supply Cap
    function testSupplyCap() public {
        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SupplyCapChange(1);
        stp.setSupplyCap(1);
        (uint256 count, uint256 supply) = stp.supplyDetail();
        assertEq(supply, 1);
        assertEq(count, 0);
        vm.stopPrank();
        mint(alice, 1e18);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.TierHasNoSupply.selector, 1));
        stp.mint{value: 1e18}(1e18);
        vm.stopPrank();

        vm.startPrank(creator);
        stp.setSupplyCap(0);
        vm.stopPrank();

        mint(bob, 1e18);
        vm.startPrank(creator);
        vm.expectRevert("Supply cap must be >= current count or 0");
        stp.setSupplyCap(1);
        vm.stopPrank();
    }
}
