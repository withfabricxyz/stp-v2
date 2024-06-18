// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract MintingTest is BaseTest {
    using SubscriberLib for Subscription;

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
        assertEq(stp.balanceOf(alice), 30 days);
        assertEq(stp.subscriptionOf(alice).tokenId, 1);
        assertEq(stp.subscriptionOf(alice).tierId, 1);
        assertEq(stp.subscriptionOf(alice).expiresAt, block.timestamp + 30 days);
        assertEq(stp.subscriptionOf(alice).purchaseExpiresAt, block.timestamp + 30 days);
        assertEq(stp.ownerOf(1), alice);
    }

    function testMintExpires() public {
        uint256 time = block.timestamp;
        mint(alice, 0.001 ether);
        assertEq(stp.subscriptionOf(alice).expiresAt, time + 30 days);
        vm.warp(block.timestamp + 31 days);
        assertEq(stp.balanceOf(alice), 0);
        assertEq(stp.subscriptionOf(alice).expiresAt, time + 30 days);
    }

    function testMintFor() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(ERC721.TransferToZeroAddress.selector));
        stp.mintFor{value: 0.001 ether}(address(0), 0.001 ether);
        vm.expectEmit(true, true, false, true, address(stp));
        emit SubscriptionLib.Purchase(1, 0.001 ether, 30 days, uint48(block.timestamp + 30 days));

        vm.expectEmit(true, true, false, true, address(stp));
        emit IERC4906.MetadataUpdate(1);
        stp.mintFor{value: 0.001 ether}(bob, 0.001 ether);
        assertEq(address(stp).balance, 0.001 ether);
        assertEq(stp.balanceOf(bob), 30 days);
        assertEq(stp.balanceOf(alice), 0);
        assertEq(stp.ownerOf(1), bob);
    }

    function testMintAdvanced() public prank(alice) {
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 1, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );
        assertEq(stp.balanceOf(bob), 30 days);
    }

    function testMintInvalid() public prank(alice) {
        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidCapture.selector));
        stp.mint{value: 0.0005 ether}(0.001 ether);
    }

    function testInitialMintPrice() public {
        tierParams.initialMintPrice = 0.01 ether;
        stp = reinitStp();
        mint(alice, 0.011 ether);
        assertEq(stp.subscriptionOf(alice).expiresAt, block.timestamp + 30 days);
        mint(alice, 0.001 ether);
        assertEq(stp.subscriptionOf(alice).expiresAt, block.timestamp + 60 days);
    }

    function testMintERC20FeeTaking() public {
        TestFeeToken _token = new TestFeeToken("FIAT", "FIAT", 1e21);
        _token.transfer(alice, 1e20);
        initParams.currencyAddress = address(_token);
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
        assertEq(stp.contractDetail().subCount, 2);
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.GlobalSupplyLimitExceeded.selector));
        stp.setGlobalSupplyCap(1);

        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.GlobalSupplyCapChange(2);
        stp.setGlobalSupplyCap(2);
        vm.stopPrank();

        vm.startPrank(charlie);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionLib.GlobalSupplyLimitExceeded.selector));
        stp.mint{value: 0.001 ether}(0.001 ether);
    }

    // Price per period is whatever you want (including free)
    function testFreeMint() public {
        tierParams.pricePerPeriod = 0;
        stp = reinitStp();

        vm.startPrank(alice);
        stp.mint(0);
        assertEq(stp.balanceOf(alice), 30 days);
        stp.mint{value: 5 ether}(5 ether);
        assertEq(stp.balanceOf(alice), 60 days);
        vm.stopPrank();
    }

    function testRenewalChecks() public prank(creator) {
        tierParams.paused = true;
        stp.updateTier(1, tierParams);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierRenewalsPaused.selector));
        stp.mintFor{value: 0.001 ether}(alice, 0.001 ether);
    }

    function testMintForTierRules() public {
        vm.startPrank(creator);
        stp.createTier(tierParams); // tier 2
        vm.stopPrank();

        // Mint a new token for bob
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 2, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );

        // Disallow explicit switching unless the sender is the recipient
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidSwitch.selector));
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 1, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );

        // Ok
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 2, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 0, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );
        stp.mintFor{value: 0.001 ether}(bob, 0.001 ether);

        // Switch allowed
        vm.startPrank(bob);
        uint256 time = stp.tierBalanceOf(2, bob);
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 1, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );
        assertApproxEqAbs(stp.tierBalanceOf(1, bob), time + 30 days, 1);
        vm.stopPrank();

        // Deactivate and migrate via sponsored call
        vm.warp(stp.balanceOf(bob) + 1);
        stp.deactivateSubscription(bob);

        // Place on tier 2
        stp.mintAdvanced{value: 0.001 ether}(
            MintParams({tierId: 2, recipient: bob, referrer: address(0), referralCode: 0, purchaseValue: 0.001 ether})
        );
    }
}
