// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

// We need to create a shim contract to call the internal functions of RewardPoolLib in order to get
// foundry to generate the coverage report correctly
contract RewardCurveTestShim {
    function currentMultiplier(CurveParams memory params) external view returns (uint256 multiplier) {
        return RewardCurveLib.currentMultiplier(params);
    }

    function test() public {}
}

contract RewardCurveLibTest is BaseTest {
    RewardCurveTestShim public shim = new RewardCurveTestShim();

    // Call all methods iva RewardPoolLib.method so the coverage tool can track them
    function defaults() internal pure returns (CurveParams memory) {
        return CurveParams({numPeriods: 6, periodSeconds: 86_400, startTimestamp: 0, minMultiplier: 0, formulaBase: 2});
    }

    /// Curve Tests ///

    function testNoDecay() public {
        CurveParams memory params = defaults();
        params.numPeriods = 0;
        params.minMultiplier = 1;
        params.startTimestamp = uint48(1);
        assertEq(shim.currentMultiplier(params), 1);
        vm.warp(block.timestamp + 365 days);
        assertEq(shim.currentMultiplier(params), 1);
    }

    function testSinglePeriod() public {
        CurveParams memory params = defaults();
        assertEq(shim.currentMultiplier(params), 64);
        vm.warp(block.timestamp + 1 + 1 days);
        assertEq(shim.currentMultiplier(params), 32);
    }

    function testZeroMin() public {
        CurveParams memory params = defaults();
        vm.warp(block.timestamp + 30 days);
        assertEq(params.minMultiplier, 0);
        assertEq(shim.currentMultiplier(params), 0);
    }

    function testOneMin() public {
        CurveParams memory params = defaults();
        params.minMultiplier = 1;
        vm.warp(block.timestamp + 20 days);
        assertEq(shim.currentMultiplier(params), 1);
    }

    function testMinMultiplierIsMin() public {
        CurveParams memory params = defaults();
        params.minMultiplier = 16;
        vm.warp(block.timestamp + 2 days);
        assertEq(shim.currentMultiplier(params), 16);
        vm.warp(block.timestamp + 1 days);
        assertEq(shim.currentMultiplier(params), 16);
        vm.warp(block.timestamp + 365 days);
        assertEq(shim.currentMultiplier(params), 16);
    }

    function testZeroPeriods() public {
        CurveParams memory params = defaults();
        params.numPeriods = 0;
        assertEq(shim.currentMultiplier(params), 0);
    }

    function testFuzzDecay(uint8 periods) public {
        vm.assume(periods > 0);
        vm.assume(periods <= 64);

        CurveParams memory params = defaults();
        params.numPeriods = periods;
        uint256 start = block.timestamp;
        for (uint256 i = 0; i <= params.numPeriods; i++) {
            vm.warp(start + (params.periodSeconds * i) + 1);
            assertEq(shim.currentMultiplier(params), (2 ** (params.numPeriods - i)));
        }
        vm.warp(start + (params.periodSeconds * (params.numPeriods + 1)) + 1);
        assertEq(shim.currentMultiplier(params), params.minMultiplier);
    }
}
