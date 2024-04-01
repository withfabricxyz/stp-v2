// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract MintingTest is BaseTest {
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

    function testMint() public {
        mint(alice, 0.001 ether);
        assertTrue(stp.balanceOf(alice) > 0);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(sub.tokenId, 1);
        assertEq(sub.tierId, 1);
        assertEq(sub.secondsPurchased, 30 days);
        assertEq(sub.secondsGranted, 0);
    }

    function testMintFor() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidAccount.selector));
        stp.mintFor{value: 0.001 ether}(address(0), 0.001 ether);
        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.Purchase(bob, 1, 0.001 ether, 30 days, 0, block.timestamp + 30 days);
        stp.mintFor{value: 0.001 ether}(bob, 0.001 ether);
        assertEq(address(stp).balance, 0.001 ether);
        assertEq(stp.balanceOf(bob), 30 days);
        assertEq(stp.balanceOf(alice), 0);
        Subscription memory sub = stp.subscriptionOf(bob);
        assertEq(stp.ownerOf(sub.tokenId), bob);
    }

    function testMintInvalid() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidCapture.selector));
        stp.mint{value: 0.0005 ether}(0.001 ether);
    }

    function testInitialMintPrice() public {
        tierParams.initialMintPrice = 0.01 ether;
        stp = reinitStp();
        mint(alice, 0.011 ether);
        Subscription memory sub = stp.subscriptionOf(alice);
        assertEq(sub.secondsPurchased, 30 days);
        mint(alice, 0.001 ether);
        sub = stp.subscriptionOf(alice);
        assertEq(sub.secondsPurchased, 60 days);
    }

    function testMintERC20FeeTaking() public {
        TestFeeToken _token = new TestFeeToken("FIAT", "FIAT", 1e21);
        _token.transfer(alice, 1e20);
        initParams.erc20TokenAddr = address(_token);
        reinitStp();
        vm.startPrank(alice);
        _token.approve(address(stp), 1e18);
        stp.mint(0.002 ether); // takes 50%
        assertEq(stp.balanceOf(alice), 30 days);
        vm.stopPrank();
    }

    function testMintSpaced() public {
        mint(alice, 0.001 ether);
        assertEq(stp.balanceOf(alice), 30 days);
        vm.warp(block.timestamp + 31 days);
        assertEq(stp.balanceOf(alice), 0);
        mint(alice, 0.001 ether);
        assertEq(stp.balanceOf(alice), 30 days);
    }

    function testGlobalSupplyCap() public {
        mint(alice, 0.001 ether);
        mint(bob, 0.001 ether);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.GlobalSupplyLimitExceeded.selector));
        stp.setGlobalSupplyCap(1);

        vm.expectEmit(true, true, false, true, address(stp));
        emit ISubscriptionTokenV2.GlobalSupplyCapChange(2);
        stp.setGlobalSupplyCap(2);
        vm.stopPrank();

        vm.startPrank(charlie);
        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.GlobalSupplyLimitExceeded.selector));
        stp.mint{value: 0.001 ether}(0.001 ether);
    }

    function testTierJoinChecks() public {}

    function testNewMintChecks() public {}

    function testRenewalChecks() public prank(creator) {
        stp.pauseTier(1);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierRenewalsPaused.selector));
        stp.mintFor{value: 0.001 ether}(alice, 0.001 ether);
    }

    // Mint Params
}
