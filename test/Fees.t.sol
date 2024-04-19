// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract FeesTest is BaseTest {
    function setUp() public {
        deal(alice, 1e19);
        deal(bob, 1e19);
        deal(charlie, 1e19);
        deal(creator, 1e19);
        deal(fees, 1e19);

        feeParams.bips = 500;
        feeParams.collector = fees;
        reinitStp();
    }

    function testPool() public {
        // (address recipient, uint16 bps) = stp.feeParams();

        assertEq(500, stp.contractDetail().feeBps);
        assertEq(fees, stp.contractDetail().feeCollector);

        uint256 expectedFee = (1e18 * 500) / 10_000;
        // uint256 balance = creator.balance;

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.FeeTransfer(fees, expectedFee);
        stp.mint{value: 1e18}(1e18);
        vm.stopPrank();
    }

    function testFeeCollectorUpdate() public {
        vm.startPrank(fees);
        vm.expectEmit(true, true, false, true, address(stp));
        emit STPV2.FeeCollectorChange(charlie);
        stp.updateFeeRecipient(charlie);
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.NotAuthorized.selector));
        stp.updateFeeRecipient(charlie);
        vm.stopPrank();
    }

    function testFeeCollectorRelinquish() public {
        vm.startPrank(fees);
        stp.updateFeeRecipient(address(0));
        vm.stopPrank();

        assertEq(stp.contractDetail().feeCollector, address(0));
        assertEq(stp.contractDetail().feeBps, 0);
    }
}
