// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams, Subscription} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {AccessControlled} from "src/abstracts/AccessControlled.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";

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
        emit ISubscriptionTokenV2.Purchase(alice, 1, 1e18, 1e18 / 2, 0, block.timestamp + (1e18 / 2));
        stp.mint{value: 1e18}(1e18);
        assertEq(address(stp).balance, 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(stp.ownerOf(sub.tokenId), alice);
        assertEq(sub.secondsPurchased, 1e18 / 2);
        assertEq(sub.rewardPoints, 0);
        // assertEq(sub.expiresAt, block.timestamp + (1e18 / 2)); // TODO
    }

    function testMintInvalid() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(PoolLib.PurchaseAmountMustMatchValueSent.selector, 1e18, 1e17));
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
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidAccount.selector));
        stp.mintFor{value: 1e18}(address(0), 1e18);

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Purchase(bob, 1, 1e18, 1e18 / 2, 0, block.timestamp + (1e18 / 2));
        stp.mintFor{value: 1e18}(bob, 1e18);
        assertEq(address(stp).balance, 1e18);
        assertEq(stp.balanceOf(bob), 5e17);
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(bob);
        assertEq(stp.ownerOf(sub.tokenId), bob);
    }

    function testMintForErc20() public erc20 prank(alice) {
        token().approve(address(stp), 1e18);
        stp.mintFor(bob, 1e18);
        assertEq(token().balanceOf(address(stp)), 1e18);
        assertEq(stp.balanceOf(bob), 5e17);
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(bob);
        assertEq(stp.ownerOf(sub.tokenId), bob);
    }

    function testNonSub() public {
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, sub.tokenId));
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
        emit ISubscriptionTokenV2.Withdraw(creator, 2e18);
        stp.withdraw();
        assertEq(stp.creatorBalance(), 0);
        assertEq(stp.totalCreatorEarnings(), 2e18);

        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.withdraw();
        vm.stopPrank();

        assertEq(address(stp).balance, 0);
    }

    function testTransferEarnings() public {
        uint256 aliceBalance = alice.balance;
        mint(alice, 1e18);
        address invalid = address(this);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidRecipient.selector));
        stp.withdrawTo(address(0));

        vm.expectRevert(abi.encodeWithSelector(PoolLib.FailedToTransferEther.selector, invalid, 1e18));
        stp.withdrawTo(invalid);
        stp.withdrawTo(alice);
        vm.stopPrank();
        assertEq(aliceBalance, alice.balance);
    }

    /// ERC20

    function testERC20Mint() public erc20 prank(alice) {
        assert(stp.erc20Address() != address(0));
        assertEq(token().balanceOf(alice), 1e20);
        token().approve(address(stp), 1e18);
        stp.mint(1e18);
        assertEq(token().balanceOf(address(stp)), 1e18);
        assertEq(stp.balanceOf(alice), 5e17);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(stp.ownerOf(sub.tokenId), alice);
    }

    function testMintInvalidERC20() public erc20 prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(PoolLib.NativeTokensNotAcceptedForERC20Subscriptions.selector));
        stp.mint{value: 1e17}(1e18);
        vm.expectRevert(
            abi.encodeWithSelector(PoolLib.InsufficientBalanceOrAllowance.selector, token().balanceOf(alice), 0)
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
        emit ISubscriptionTokenV2.Withdraw(creator, 2e18);
        stp.withdraw();
        assertEq(stp.creatorBalance(), 0);
        assertEq(stp.totalCreatorEarnings(), 2e18);

        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidZeroTransfer.selector));
        stp.withdraw();
        vm.stopPrank();

        assertEq(beforeBalance + 2e18, token().balanceOf(creator));
    }

    function testTransfer() public {
        mint(alice, 1e18);
        Subscription memory sub = stp.subscriptionOf(alice);
        vm.startPrank(alice);
        stp.approve(bob, sub.tokenId);
        vm.expectEmit(true, true, false, true, address(stp));
        emit IERC721.Transfer(alice, bob, sub.tokenId);
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

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlled.NotAuthorized.selector
            )
        );
        stp.updateMetadata("x");
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
        vm.expectRevert(abi.encodeWithSelector(PoolLib.InvalidRecipient.selector));
        stp.transferAllBalances();

        vm.startPrank(creator);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.TransferRecipientChange(charlie);
        stp.setTransferRecipient(charlie);
        vm.stopPrank();

        assertEq(charlie, stp.transferRecipient());

        stp.transferAllBalances();

        assertEq(charlie.balance, balance + 2e18);
    }

}
