// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams, DeployParams, Tier, RewardParams} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {SubscriptionTokenV2Factory} from "src/SubscriptionTokenV2Factory.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SubscriptionTokenV2FactoryTest is BaseTest {
    /// @dev Emitted upon a successful contract deployment
    event Deployment(address indexed deployment, uint256 feeId);

    /// @dev Emitted when a new fee is created
    event FeeCreated(uint256 indexed id, address collector, uint16 bips);

    /// @dev Emitted when a fee is destroyed
    event FeeDestroyed(uint256 indexed id);

    /// @dev Emitted when the deployment fee changes
    event DeployFeeChange(uint256 amount);

    /// @dev Emitted when the deploy fees are collected by the owner
    event DeployFeeTransfer(address indexed recipient, uint256 amount);

    SubscriptionTokenV2 internal impl;
    SubscriptionTokenV2Factory internal factory;

    function setUp() public {
        impl = new SubscriptionTokenV2();
        factory = new SubscriptionTokenV2Factory(address(impl));
        deal(alice, 1e19);
    }

    // function deploy (InitParams memory params) public returns (address) {
    //     return factory.deploySubscription(
    //         params.name,
    //         params.symbol,
    //         params.contractUri,
    //         params.tokenUri,
    //         params.tokensPerSecond,
    //         params.minimumPurchaseSeconds,
    //         params.bips,
    //         params.erc20TokenAddr,
    //         params.feeBps
    //     );
    // }

    function testDeployment() public {
        vm.startPrank(alice);

        DeployParams memory params =
            DeployParams({feeConfigId: 0, initParams: initParams, tierParams: tierParams, rewardParams: rewardParams});

        vm.expectEmit(false, false, false, true, address(factory));
        emit Deployment(address(1), 0);
        address deployment = factory.deploySubscription(params);

        SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
        assertEq(nft.name(), "Meow Sub");
        assertEq(nft.symbol(), "MEOW");
        assertEq(nft.contractURI(), "curi");
        assertEq(nft.timeValue(2), 1);
        assertEq(nft.erc20Address(), address(0));
        assertEq(nft.bips(), 0);
    }

    // function testDeploymentWithReferral() public {
    //     factory.createFee(1, bob, 100);
    //     vm.startPrank(alice);
    //     vm.expectEmit(false, false, false, true, address(factory));
    //     emit Deployment(address(1), 1);
    //     address deployment = factory.deploySubscription("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 1);
    //     SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
    //     (address recipient, uint16 bps) = nft.feeSchedule();
    //     assertEq(recipient, bob);
    //     assertEq(bps, 100);
    // }

    // function testInvalidReferral() public {
    //     factory.createFee(0, bob, 100);
    //     vm.startPrank(alice);
    //     vm.expectEmit(false, false, false, true, address(factory));
    //     emit Deployment(address(1), 1);
    //     address deployment = factory.deploySubscription("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 1);
    //     SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
    //     (address recipient, uint16 bps) = nft.feeSchedule();
    //     assertEq(recipient, bob);
    //     assertEq(bps, 100);
    // }

    // function testFeeCreate() public {
    //     vm.expectEmit(true, true, true, true, address(factory));
    //     emit FeeCreated(1, bob, 100);
    //     factory.createFee(1, bob, 100);

    //     (address addr, uint16 bips, uint256 deploy) = factory.feeInfo(1);
    //     assertEq(bob, addr);
    //     assertEq(100, bips);
    //     assertEq(0, deploy);
    // }

    // function testFeeCreateInvalid() public {
    //     vm.expectRevert("Fee exceeds maximum");
    //     factory.createFee(1, bob, 2000);
    //     vm.expectRevert("Fee cannot be 0");
    //     factory.createFee(1, bob, 0);
    //     vm.expectRevert("Collector cannot be 0x0");
    //     factory.createFee(1, address(0), 100);

    //     // Valid
    //     factory.createFee(1, bob, 100);
    //     vm.expectRevert("Fee exists");
    //     factory.createFee(1, alice, 100);
    // }

    // function testFeeDestroy() public {
    //     factory.createFee(1, bob, 100);
    //     factory.destroyFee(1);

    //     vm.expectRevert("Fee does not exists");
    //     factory.destroyFee(1);
    // }

    // function testDeployFeeUpdate() public {
    //     vm.expectEmit(true, true, true, true, address(factory));
    //     emit DeployFeeChange(1e12);
    //     factory.updateMinimumDeployFee(1e12);

    //     (address addr, uint16 bips, uint256 deploy) = factory.feeInfo(0);
    //     assertEq(address(0), addr);
    //     assertEq(0, bips);
    //     assertEq(1e12, deploy);

    //     vm.startPrank(alice);
    //     vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
    //     factory.updateMinimumDeployFee(1e12);
    // }

    // function testDeployFeeTooLow() public {
    //     factory.updateMinimumDeployFee(1e12);
    //     vm.expectRevert("Insufficient ETH to deploy");
    //     factory.deploySubscription("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 0);
    // }

    // function testDeployFeeCollectNone() public {
    //     vm.expectRevert("No fees to collect");
    //     factory.transferDeployFees(alice);
    // }

    // function testDeployFeeCapture() public {
    //     factory.updateMinimumDeployFee(1e12);
    //     factory.deploySubscription{value: 1e12}("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 0);
    //     assertEq(1e12, address(factory).balance);
    // }

    // function testDeployFeeTransfer() public {
    //     factory.updateMinimumDeployFee(1e12);
    //     factory.deploySubscription{value: 1e12}("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 0);
    //     vm.expectEmit(true, true, true, true, address(factory));
    //     emit DeployFeeTransfer(alice, 1e12);
    //     uint256 beforeBalance = alice.balance;
    //     factory.transferDeployFees(alice);
    //     assertEq(beforeBalance + 1e12, alice.balance);
    //     assertEq(0, address(factory).balance);
    // }

    // function testDeployFeeTransferNonOwner() public {
    //     factory.updateMinimumDeployFee(1e12);
    //     factory.deploySubscription{value: 1e12}("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 0);
    //     vm.startPrank(alice);
    //     vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
    //     factory.transferDeployFees(alice);
    // }

    // function testDeployFeeTransferBadReceiver() public {
    //     factory.updateMinimumDeployFee(1e12);
    //     factory.deploySubscription{value: 1e12}("test", "tst", "curi", "turi", 1e9, 2e9, 0, address(0), 0);
    //     vm.expectRevert("Failed to transfer Ether");
    //     factory.transferDeployFees(address(this));
    // }

    function testTransferAccept() public {
        factory.transferOwnership(alice);
        vm.startPrank(alice);
        factory.acceptOwnership();
        vm.stopPrank();
        assertEq(factory.owner(), alice);
    }
}
