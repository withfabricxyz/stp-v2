// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BaseTest, TestERC20Token, TestERC1155Token} from "../TestHelpers.t.sol";
import {GateLib} from "src/libraries/GateLib.sol";
import {Gate, GateType, Tier} from "src/types/Index.sol";

contract GateTestShim {
    function validate(Gate memory gate) external pure returns (Gate memory) {
        return GateLib.validate(gate);
    }

    function checkAccount(Gate memory gate, address account) external view {
        GateLib.checkAccount(gate, account);
    }

    function balanceOf(Gate memory gate, address account) external view returns (uint256) {
        return GateLib.balanceOf(gate, account);
    }
}

contract GateLibTest is BaseTest {
    GateTestShim public shim = new GateTestShim();

    function defaults() internal pure returns (Gate memory) {
        return Gate({gateType: GateType.NONE, contractAddress: address(0), componentId: 0, balanceMin: 1});
    }

    function testValidation() public {
        Gate memory gate = defaults();
        shim.validate(gate);

        gate.gateType = GateType.ERC20;
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateInvalid.selector));
        shim.validate(gate);

        gate.contractAddress = address(1);
        gate.balanceMin = 0;
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateInvalid.selector));
        shim.validate(gate);

        gate.balanceMin = 1;
        gate.gateType = GateType.ERC1155;
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateInvalid.selector));
        shim.validate(gate);

        gate.componentId = 2 ** 17;
        shim.validate(gate);

        gate.gateType = GateType.STPV2;
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateInvalid.selector));
        shim.validate(gate);
    }

    function testNone() public {
        Gate memory gate = defaults();
        shim.checkAccount(gate, alice);
        assertEq(shim.balanceOf(gate, alice), 0);
    }

    function testERC20() public {
        TestERC20Token token = new TestERC20Token("FIAT", "FIAT", 18);
        token.transfer(alice, 499);

        Gate memory gate = defaults();
        gate.gateType = GateType.ERC20;
        gate.contractAddress = address(token);
        gate.balanceMin = 500;

        assertEq(shim.balanceOf(gate, alice), 499);
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateCheckFailure.selector));
        shim.checkAccount(gate, alice);

        token.transfer(alice, 1);
        assertEq(shim.balanceOf(gate, alice), 500);
        shim.checkAccount(gate, alice);
    }

    function testERC721() public {
        // Use STP as a mock ERC721
        stp = reinitStp();

        Gate memory gate = defaults();
        gate.gateType = GateType.ERC721;
        gate.contractAddress = address(stp);

        assertEq(shim.balanceOf(gate, alice), 0);

        stp.mintFor{value: 1e15}(alice, 1e15);
        assertGt(shim.balanceOf(gate, alice), 1);
    }

    function testERC1155() public prank(creator) {
        TestERC1155Token token = new TestERC1155Token();

        Gate memory gate = defaults();
        gate.gateType = GateType.ERC1155;
        gate.componentId = 1;
        gate.contractAddress = address(token);

        assertEq(shim.balanceOf(gate, alice), 0);

        token.mint(alice, 1, 1);
        assertEq(shim.balanceOf(gate, alice), 1);
    }

    function testSTPv2NoTier() public {
        stp = reinitStp();
        Gate memory gate = defaults();
        gate.gateType = GateType.STPV2;
        gate.contractAddress = address(stp);

        assertEq(shim.balanceOf(gate, alice), 0);
        stp.mintFor{value: 1e15}(alice, 1e15);
        assertGt(shim.balanceOf(gate, alice), 1);
    }

    function testSTPv2SpecificTier() public {
        stp = reinitStp();
        Gate memory gate = defaults();
        gate.gateType = GateType.STPV2;
        gate.componentId = 2;
        gate.contractAddress = address(stp);

        vm.startPrank(creator);
        stp.createTier(
            Tier({
                id: 2,
                periodDurationSeconds: 2592000,
                paused: false,
                transferrable: true,
                maxSupply: 0,
                rewardMultiplier: 0,
                initialMintPrice: 0.01 ether,
                pricePerPeriod: 0.005 ether,
                maxCommitmentSeconds: 24 * 2592000,
                gate: defaults()
            })
        );
        vm.stopPrank();

        stp.mintFor{value: 1e15}(alice, 1e15);
        assertEq(shim.balanceOf(gate, alice), 0);
        gate.componentId = 1;
        assertGt(shim.balanceOf(gate, alice), 1);
    }
}
