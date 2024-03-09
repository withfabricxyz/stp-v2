// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";
import {RewardLib} from "src/libraries/RewardLib.sol";
import {RewardParams} from "src/types/InitParams.sol";

contract RewardLibTest is Test {
    using RewardLib for RewardParams;

    RewardParams params;

    function setUp() public {
        params = RewardParams({bips: 500, numPeriods: 6, periodSeconds: 86400, startTimestamp: 0, minMultiplier: 0});
    }

    function testValid() public {
        params = params.validate();
        assertEq(params.startTimestamp, block.timestamp);
    }

    function testValidNoDecay() public {
        params.numPeriods = 0;
        params.minMultiplier = 1;
        params = params.validate();
        assertEq(params.startTimestamp, block.timestamp);
    }

    function testInvalidBips() public {
        params.bips = 10001;
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardBipsTooHigh.selector, 10001));
        params = params.validate();
    }

    function testInvalidFormula() public {
        params.numPeriods = 0;
        params.minMultiplier = 0;
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardInvalidFormula.selector));
        params = params.validate();
    }

    function testSinglePeriod() public {
        assertEq(params.currentMultiplier(), 64);
        vm.warp(block.timestamp + 1 + 1 days);
        assertEq(params.currentMultiplier(), 32);
    }

    function testZeroMin() public {
        vm.warp(block.timestamp + 20 days);
        assertEq(params.currentMultiplier(), 0);
    }

    function testOneMin() public {
        params.minMultiplier = 1;
        vm.warp(block.timestamp + 20 days);
        assertEq(params.currentMultiplier(), 1);
    }

    function testFuzzDecay(uint8 periods) public {
        vm.assume(periods > 0);
        vm.assume(periods < 32);

        params.numPeriods = periods;
        uint256 start = block.timestamp;
        for (uint256 i = 0; i <= params.numPeriods; i++) {
            vm.warp(start + (params.periodSeconds * i) + 1);
            assertEq(params.currentMultiplier(), (2 ** (params.numPeriods - i)));
        }
        vm.warp(start + (params.periodSeconds * (params.numPeriods + 1)) + 1);
        assertEq(params.currentMultiplier(), params.minMultiplier);
    }
}
