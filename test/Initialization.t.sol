// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract InitializationTest is BaseTest {
    InitParams private params;

    function setUp() public {
        stp = new STPV2();
        vm.store(
            address(stp),
            bytes32(uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132)),
            bytes32(0)
        );
    }

    function testDefaults() public {
        stp = reinitStp();
        assertEq(initParams.owner, stp.owner());
        assertEq(initParams.name, stp.name());
        assertEq(initParams.symbol, stp.symbol());
        assertEq(initParams.contractUri, stp.contractURI());

        // More
        assertEq(initParams.erc20TokenAddr, stp.contractDetail().currency);
        assertEq(initParams.globalSupplyCap, stp.contractDetail().supplyCap);
    }

    function testOwnerZero() public {
        initParams.owner = address(0);

        vm.expectRevert(abi.encodeWithSelector(ISTPV2.InvalidOwner.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }

    function testFeeBps() public {
        feeParams.bips = 1500;

        vm.expectRevert(abi.encodeWithSelector(ISTPV2.InvalidFeeParams.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }

    function testFeeRequirement() public {
        feeParams.collector = fees;

        vm.expectRevert(abi.encodeWithSelector(ISTPV2.InvalidFeeParams.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }

    function testMinPurchase() public {
        tierParams.periodDurationSeconds = 0;

        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidDuration.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }

    function testEmptyName() public {
        initParams.name = "";

        vm.expectRevert(abi.encodeWithSelector(ISTPV2.InvalidTokenParams.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }

    function testEmptySymbol() public {
        initParams.symbol = "";

        vm.expectRevert(abi.encodeWithSelector(ISTPV2.InvalidTokenParams.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }

    function testEmptyContractURI() public {
        initParams.contractUri = "";

        vm.expectRevert(abi.encodeWithSelector(ISTPV2.InvalidTokenParams.selector));
        stp.initialize(initParams, tierParams, rewardParams, curveParams, feeParams);
    }
}
