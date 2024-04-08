// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";
import {STPV2Factory} from "src/STPV2Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract FactoryTest is BaseTest {
    SubscriptionTokenV2 internal impl;
    RewardPool internal rpImpl;
    STPV2Factory internal factory;
    FactoryFeeConfig internal fee;

    function setUp() public {
        impl = new SubscriptionTokenV2();
        rpImpl = new RewardPool();
        factory = new STPV2Factory(address(impl), address(rpImpl));
        fee = FactoryFeeConfig({collector: bob, basisPoints: 100, deployFee: 0});
        deal(alice, 1e19);
    }

    function defaultParams() internal view returns (DeployParams memory) {
        return
            DeployParams({feeConfigId: 0, initParams: initParams, tierParams: tierParams, rewardParams: rewardParams});
    }

    function testRewardPoolDeployment() public {
        RewardCurveParams memory poolParams = defaultPoolParams();
        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.RewardPoolDeployment(address(1));
        RewardPool pool = RewardPool(payable(factory.deployRewardPool(poolParams)));
        // assertEq(pool.name(), "Rewards");
    }

    function testSubAndPoolDeployment() public {
        DeployParams memory params = defaultParams();
        RewardCurveParams memory poolParams = defaultPoolParams();
        params.rewardParams.bips = 1000;

        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.RewardPoolDeployment(address(1));
        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.SubscriptionDeployment(address(1), 0);
        (address sub, address pool) = factory.deploySubscription(params, poolParams);

        SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(sub));
        (address poolAddr, uint16 bps) = nft.rewardParams();
        assertEq(poolAddr, pool);
        assertEq(bps, 1000);

        // Ensure NFT transfers funds to pool
        vm.startPrank(alice);
        nft.mint{value: 1e5}(1e5);
        assertEq(RewardPool(payable(pool)).balanceOf(alice), 1e5 * 64);
        vm.stopPrank();
    }

    function testDeployment() public {
        vm.startPrank(alice);

        DeployParams memory params = defaultParams();

        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.SubscriptionDeployment(address(1), 0);
        address deployment = factory.deploySubscription(params);

        SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
        assertEq(nft.name(), "Meow Sub");
        assertEq(nft.symbol(), "MEOW");
        assertEq(nft.contractURI(), "curi");
        assertEq(nft.erc20Address(), address(0));
    }

    function testDeployZeroAddr() public {
        vm.startPrank(alice);

        DeployParams memory params = defaultParams();
        params.initParams.owner = address(0);

        address deployment = factory.deploySubscription(params);

        SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
        assertEq(nft.owner(), alice);
    }

    function testDeploymentWithReferral() public {
        factory.createFee(1, fee);
        DeployParams memory params = defaultParams();
        params.feeConfigId = 1;

        vm.startPrank(alice);
        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.SubscriptionDeployment(address(1), 1);
        address deployment = factory.deploySubscription(params);
        SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
        (address recipient, uint16 bps) = nft.feeParams();
        assertEq(recipient, bob);
        assertEq(bps, 100);
    }

    function testInvalidReferral() public {
        factory.createFee(0, fee);
        DeployParams memory params = defaultParams();
        params.feeConfigId = 1;

        vm.startPrank(alice);
        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.SubscriptionDeployment(address(1), 1); // ?
        address deployment = factory.deploySubscription(params);
        SubscriptionTokenV2 nft = SubscriptionTokenV2(payable(deployment));
        (address recipient, uint16 bps) = nft.feeParams();
        assertEq(recipient, bob);
        assertEq(bps, 100);
    }

    function testFeeCreate() public {
        vm.expectEmit(true, true, true, true, address(factory));
        emit STPV2Factory.FeeCreated(1, bob, 100, 0);
        factory.createFee(1, fee);

        FactoryFeeConfig memory result = factory.feeInfo(1);
        assertEq(bob, result.collector);
        assertEq(100, result.basisPoints);
        assertEq(0, result.deployFee);
    }

    function testFeeCreateInvalid() public {
        fee.basisPoints = 2000;
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeBipsInvalid.selector));
        factory.createFee(1, fee);

        fee.basisPoints = 0;
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeBipsInvalid.selector));
        factory.createFee(1, fee);

        fee.basisPoints = 100;
        fee.collector = address(0);
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeCollectorInvalid.selector));
        factory.createFee(1, fee);

        // Valid
        fee.collector = bob;
        factory.createFee(1, fee);
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeExists.selector, 1));
        factory.createFee(1, fee);
    }

    function testFeeDestroy() public {
        factory.createFee(1, fee);
        factory.destroyFee(1);

        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeNotFound.selector, 1));
        factory.destroyFee(1);
    }

    function testDeployFeeTooLow() public {
        fee.deployFee = 1e12;
        factory.createFee(0, fee);
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeInsufficient.selector, 1e12));
        factory.deploySubscription(defaultParams());
    }

    function testDeployFeeCapture() public {
        fee.deployFee = 1e12;
        factory.createFee(0, fee);
        factory.deploySubscription{value: 1e12}(defaultParams());
        assertEq(1e12, bob.balance);
    }

    function testDeployFeeTransferBadReceiver() public {
        fee.deployFee = 1e12;
        fee.collector = address(this);
        factory.createFee(0, fee);
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeTransferFailed.selector));
        factory.deploySubscription{value: 1e12}(defaultParams());
    }

    function testTransferAccept() public {
        factory.transferOwnership(alice);
        vm.startPrank(alice);
        factory.acceptOwnership();
        vm.stopPrank();
        assertEq(factory.owner(), alice);
    }
}
