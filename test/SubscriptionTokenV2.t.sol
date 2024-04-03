// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract SubscriptionTokenV2Test is BaseTest {
    function setUp() public {
        tierParams.periodDurationSeconds = 4;
        tierParams.pricePerPeriod = 8;
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
        stp.mintFor(bob, 1e5);
        assertEq(token().balanceOf(address(stp)), 1e5);
        assertEq(stp.balanceOf(bob), 1e5 / 2);
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(bob);
        assertEq(stp.ownerOf(sub.tokenId), bob);
    }

    function testNonSub() public {
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721.TokenDoesNotExist.selector));
        stp.ownerOf(sub.tokenId);
    }

    function testMintExpire() public prank(alice) {
        uint256 time = block.timestamp;
        stp.mint{value: 1e18}(1e18);
        vm.warp(block.timestamp + 6e17);
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(alice);
        // assertEq(expires, time + 1e18 / 2); //TODO
        assertEq(stp.ownerOf(sub.tokenId), alice);
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
        emit ISubscriptionTokenV2.Withdraw(creator, 2e18);
        stp.transferFunds(creator, stp.creatorBalance());
        assertEq(stp.creatorBalance(), 0);

        // vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.transferFunds(creator, stp.creatorBalance());
        vm.stopPrank();

        assertEq(address(stp).balance, 0);
    }

    function testTransferEarnings() public {
        uint256 aliceBalance = alice.balance;
        mint(alice, 1e18);
        address invalid = address(this);
        vm.startPrank(creator);
        uint256 balance = stp.creatorBalance();
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
        assert(stp.erc20Address() != address(0));
        assertEq(token().balanceOf(alice), 1e20);
        token().approve(address(stp), 1e18);
        stp.mint(1e5);
        assertEq(token().balanceOf(address(stp)), 1e5);
        assertEq(stp.balanceOf(alice), 1e5 / 2);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(stp.ownerOf(sub.tokenId), alice);
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
        assertEq(stp.creatorBalance(), 2e18);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Withdraw(creator, 2e18);
        stp.transferFunds(creator, stp.creatorBalance());
        assertEq(stp.creatorBalance(), 0);

        // vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.transferFunds(creator, stp.creatorBalance());
        vm.stopPrank();

        assertEq(beforeBalance + 2e18, token().balanceOf(creator));
    }

    function testTransfer() public {
        mint(alice, 1e18);
        Subscription memory sub = stp.subscriptionOf(alice);
        vm.startPrank(alice);
        stp.approve(bob, sub.tokenId);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ERC721.Transfer(alice, bob, sub.tokenId);
        stp.transferFrom(alice, bob, sub.tokenId);
        vm.stopPrank();
        assertEq(stp.ownerOf(sub.tokenId), bob);
    }

    function testTransferToExistingHolder() public {
        mint(alice, 1e18);
        mint(bob, 1e18);
        Subscription memory sub = stp.subscriptionOf(alice);
        vm.startPrank(alice);
        stp.approve(bob, sub.tokenId);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidTransfer.selector));
        stp.transferFrom(alice, bob, sub.tokenId);
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

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidContractUri.selector));
        stp.updateMetadata("");
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.updateMetadata("x");
    }
}
