// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {STPV2Factory} from "src/STPV2Factory.sol";

contract FactoryTest is BaseTest {
    STPV2 internal impl;
    STPV2Factory internal factory;

    function setUp() public {
        impl = new STPV2();
        factory = new STPV2Factory(address(impl), fees);
        deal(alice, 1e19);
    }

    function defaultParams() internal view returns (DeployParams memory) {
        return DeployParams({
            clientFeeBps: 400,
            clientReferralShareBps: 0,
            clientFeeRecipient: fees,
            deployKey: "hello",
            initParams: initParams,
            tierParams: tierParams,
            rewardParams: rewardParams,
            curveParams: curveParams
        });
    }

    function testInvalidFactory() public {
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.InvalidFeeRecipient.selector));
        new STPV2Factory(address(impl), address(0));

        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.InvalidImplementation.selector));
        new STPV2Factory(address(0), fees);
    }

    function testDeployment() public {
        vm.startPrank(alice);

        DeployParams memory params = defaultParams();

        vm.expectEmit(false, false, false, true, address(factory));
        emit STPV2Factory.Deployment(address(1), "hello");
        address deployment = factory.deploySubscription(params);

        STPV2 stp = STPV2(payable(deployment));
        assertEq(stp.name(), "Meow Sub");
        assertEq(stp.symbol(), "MEOW");
        assertEq(stp.contractURI(), "curi");
        assertEq(stp.contractDetail().currency, address(0));
        assertEq(stp.owner(), creator);
        assertEq(100, stp.feeDetail().protocolBps);
        assertEq(400, stp.feeDetail().clientBps);
        assertEq(fees, stp.feeDetail().protocolRecipient);
        assertEq(fees, stp.feeDetail().clientRecipient);
    }

    function testDeployZeroAddr() public {
        vm.startPrank(alice);

        DeployParams memory params = defaultParams();
        params.initParams.owner = address(0);

        address deployment = factory.deploySubscription(params);

        STPV2 stp = STPV2(payable(deployment));
        assertEq(stp.owner(), alice);
    }

    function testDeployFeeTooLow() public {
        factory.setDeployFee(1e12);
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.FeeInvalid.selector));
        factory.deploySubscription(defaultParams());
    }

    function testDeployFeeCapture() public {
        vm.expectEmit(true, true, false, true, address(factory));
        emit STPV2Factory.DeployFeeChange(1e12);
        factory.setDeployFee(1e12);

        vm.expectEmit(true, true, false, true, address(factory));
        emit STPV2Factory.ProtocolFeeRecipientChange(bob);
        factory.setProtocolFeeRecipient(bob);

        assertEq(factory.feeSchedule().deployFee, 1e12);
        assertEq(factory.feeSchedule().protocolFeeBps, 100);
        assertEq(factory.feeSchedule().recipient, bob);

        factory.deploySubscription{value: 1e12}(defaultParams());
        assertEq(1e12, bob.balance);
    }

    function testBadFeeRecipient() public {
        vm.expectRevert(abi.encodeWithSelector(STPV2Factory.InvalidFeeRecipient.selector));
        factory.setProtocolFeeRecipient(address(0));
    }

    function testDeployFeeTransferBadReceiver() public {
        factory.setDeployFee(1e12);
        factory.setProtocolFeeRecipient(address(this));

        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        factory.deploySubscription{value: 1e12}(defaultParams());
    }

    function testTransferAccept() public {
        factory.setPendingOwner(alice);
        vm.startPrank(alice);
        factory.acceptOwnership();
        vm.stopPrank();
        assertEq(factory.owner(), alice);
    }

    function testUpdateProtocolFees() public {
        address payable deployment = payable(factory.deploySubscription(defaultParams()));
        STPV2 stp = STPV2(deployment);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(factory.updateClientFeeRecipient.selector, deployment, alice);
        calls[1] = abi.encodeWithSelector(factory.updateProtocolFeeRecipient.selector, deployment, bob);

        vm.startPrank(fees);
        factory.multicall(calls);
        vm.stopPrank();

        assertEq(stp.feeDetail().clientRecipient, alice);
        assertEq(stp.feeDetail().protocolRecipient, bob);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        factory.updateClientFeeRecipient(deployment, fees);

        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        factory.updateProtocolFeeRecipient(deployment, fees);

        vm.startPrank(alice);
        factory.updateClientFeeRecipient(deployment, bob);
        vm.stopPrank();

        assertEq(stp.feeDetail().clientRecipient, bob);
    }
}
