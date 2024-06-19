// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract STPV2Test is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 30 days;
        tierParams.pricePerPeriod = 0.001 ether;
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

    function testMintViaFallback() public prank(alice) {
        (bool sent,) = address(stp).call{value: 1e18}("");
        assertTrue(sent);
    }

    function testMintViaFallbackERC20() public erc20 prank(alice) {
        vm.expectRevert("Native tokens not accepted for ERC20 subscriptions");
        (, bytes memory data) = address(stp).call{value: 1e18}("");
        assertTrue(data.length > 0);
    }

    function testMintForErc20() public erc20 prank(alice) {
        token().approve(address(stp), 1e18);
        stp.mintFor(bob, 0.001 ether);
        assertEq(token().balanceOf(address(stp)), 0.001 ether);
        assertEq(stp.balanceOf(bob), 30 days);
        assertEq(stp.balanceOf(alice), 0);
        assertEq(stp.ownerOf(1), bob);
    }

    function testNonSub() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721.TokenDoesNotExist.selector));
        stp.ownerOf(2);
    }

    function testCreatorEarnings() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        mint(charlie, 1e18);
        assertEq(stp.contractDetail().creatorBalance, 3e18);
    }

    function testWithdraw() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        vm.startPrank(creator);
        assertEq(stp.contractDetail().creatorBalance, 2e18);

        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.Withdraw(creator, 2e18);
        stp.transferFunds(creator, stp.contractDetail().creatorBalance);
        assertEq(stp.contractDetail().creatorBalance, 0);

        // vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.transferFunds(creator, stp.contractDetail().creatorBalance);
        vm.stopPrank();

        assertEq(address(stp).balance, 0);
    }

    function testTransferEarnings() public {
        uint256 aliceBalance = alice.balance;
        mint(alice, 1e18);
        address invalid = address(this);
        vm.startPrank(creator);
        uint256 balance = stp.contractDetail().creatorBalance;
        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidAccount.selector));
        stp.transferFunds(address(0), balance);

        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        stp.transferFunds(invalid, balance);
        stp.transferFunds(alice, balance);
        vm.stopPrank();
        assertEq(aliceBalance, alice.balance);
    }

    /// ERC20

    function testERC20Mint() public erc20 prank(alice) {
        assert(stp.contractDetail().currency != address(0));
        assertEq(token().balanceOf(alice), 1e20);
        token().approve(address(stp), 1e18);
        stp.mint(0.001 ether);
        assertEq(token().balanceOf(address(stp)), 0.001 ether);
        assertEq(stp.balanceOf(alice), 30 days);
    }

    function testMintInvalidERC20() public erc20 prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidCapture.selector));
        stp.mint{value: 1e17}(1e5);
        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.TransferFromFailed.selector));
        stp.mint(1e5);
    }

    function testWithdrawERC20() public erc20 {
        mint(alice, 1e18);
        mint(bob, 1e18);

        uint256 beforeBalance = token().balanceOf(creator);
        vm.startPrank(creator);
        assertEq(stp.contractDetail().creatorBalance, 2e18);
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.Withdraw(creator, 2e18);
        stp.transferFunds(creator, stp.contractDetail().creatorBalance);
        assertEq(stp.contractDetail().creatorBalance, 0);

        // vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.transferFunds(creator, stp.contractDetail().creatorBalance);
        vm.stopPrank();

        assertEq(beforeBalance + 2e18, token().balanceOf(creator));
    }

    function testTransfer() public {
        mint(alice, 1e18);
        vm.startPrank(alice);
        stp.approve(bob, 1);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ERC721.Transfer(alice, bob, 1);
        stp.transferFrom(alice, bob, 1);
        vm.stopPrank();
        assertEq(stp.ownerOf(1), bob);
    }

    function testTransferToExistingHolder() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        vm.startPrank(alice);
        stp.approve(bob, 1);
        vm.expectRevert(abi.encodeWithSelector(STPV2.TransferToExistingSubscriber.selector));
        stp.transferFrom(alice, bob, 1);
    }

    function testDisallowedTransfer() public {
        tierParams.transferrable = false;
        stp = reinitStp();
        mint(alice, 1e18);
        vm.startPrank(alice);
        stp.approve(bob, 1);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierTransferDisabled.selector));
        stp.transferFrom(alice, bob, 1);
        vm.stopPrank();
    }

    function testUpdateMetadata() public {
        mint(alice, 1e18);

        vm.startPrank(creator);
        stp.updateMetadata("x");
        assertEq(stp.contractURI(), "x");
        assertEq(stp.tokenURI(1), "x/1");

        vm.expectRevert(abi.encodeWithSelector(STPV2.InvalidTokenParams.selector));
        stp.updateMetadata("");
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.updateMetadata("x");
    }

    function testTimedKick() public {
        mint(alice, 0.001 ether);

        vm.startPrank(creator);
        stp.grantTime(alice, 30 days, 1);
        assertEq(stp.balanceOf(alice), 60 days);
        vm.warp(block.timestamp + 5 days);
        assertEq(stp.balanceOf(alice), 60 days - 5 days);
        stp.refund(alice, 0);
        stp.revokeTime(alice);
        stp.deactivateSubscription(alice);
        vm.stopPrank();

        assertEq(stp.subscriptionOf(alice).tierId, 0);
        assertEq(stp.subscriptionOf(alice).purchaseExpiresAt, block.timestamp);
        assertEq(stp.subscriptionOf(alice).expiresAt, block.timestamp);
        assertEq(stp.balanceOf(alice), 0);
    }
}
