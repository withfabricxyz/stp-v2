// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

// We need to create a shim contract to call the internal functions of RewardLib in order to get
// foundry to generate the coverage report correctly
contract RewardTestShim {
    function validate(RewardCurveParams memory params) external view returns (RewardCurveParams memory) {
        return RewardLib.validate(params);
    }

    function currentMultiplier(RewardCurveParams memory params) external view returns (uint256 multiplier) {
        return RewardLib.currentMultiplier(params);
    }
}

contract RewardLibTest is Test {
    RewardTestShim public shim = new RewardTestShim();

    // Call all methods iva RewardLib.method so the coverage tool can track them
    function defaults() internal pure returns (RewardCurveParams memory) {
        return RewardCurveParams({
            numPeriods: 6,
            periodSeconds: 86400,
            startTimestamp: 0,
            minMultiplier: 0,
            formulaBase: 2
        });
    }

    function testValid() public {
        RewardCurveParams memory params = defaults();
        params = shim.validate(params);
        assertEq(params.startTimestamp, block.timestamp);
    }

    function testValidNoDecay() public {
        RewardCurveParams memory params = defaults();
        params.numPeriods = 0;
        params.minMultiplier = 1;
        params = shim.validate(params);
        assertEq(shim.currentMultiplier(params), 1);
        vm.warp(block.timestamp + 365 days);
        assertEq(shim.currentMultiplier(params), 1);
    }

    function testInvalidFormula() public {
        RewardCurveParams memory params = defaults();
        params.numPeriods = 128;
        params.formulaBase = 2;
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardFormulaInvalid.selector));
        params = shim.validate(params);
    }

    function testInvalidFormulaWithBips() public {
        RewardCurveParams memory params = defaults();
        params.numPeriods = 0;
        params.minMultiplier = 0;
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardFormulaInvalid.selector));
        params = shim.validate(params);
    }

    function testSinglePeriod() public {
        RewardCurveParams memory params = defaults();
        assertEq(shim.currentMultiplier(params), 64);
        vm.warp(block.timestamp + 1 + 1 days);
        assertEq(shim.currentMultiplier(params), 32);
    }

    function testZeroMin() public {
        RewardCurveParams memory params = defaults();
        vm.warp(block.timestamp + 30 days);
        assertEq(params.minMultiplier, 0);
        assertEq(shim.currentMultiplier(params), 0);
    }

    function testOneMin() public {
        RewardCurveParams memory params = defaults();
        params.minMultiplier = 1;
        vm.warp(block.timestamp + 20 days);
        assertEq(shim.currentMultiplier(params), 1);
    }

    function testZeroPeriods() public {
        RewardCurveParams memory params = defaults();
        params.numPeriods = 0;
        assertEq(shim.currentMultiplier(params), 0);
    }

    function testFuzzDecay(uint8 periods) public {
        vm.assume(periods > 0);
        vm.assume(periods <= 64);

        RewardCurveParams memory params = defaults();
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
