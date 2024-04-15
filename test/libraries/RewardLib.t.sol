// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

struct PoolStatePartial {
    uint256 totalShares;
    uint256 totalRewardIngress;
}

// We need to create a shim contract to call the internal functions of RewardLib in order to get
// foundry to generate the coverage report correctly
contract RewardTestShim {
    using RewardLib for RewardLib.State;

    RewardLib.State private _state;

    constructor() {
        // _state.currency = Currency.wrap(address(0));
        _state.createCurve(
            CurveParams({
                numPeriods: 6,
                periodSeconds: 86_400,
                startTimestamp: uint48(block.timestamp),
                minMultiplier: 0,
                formulaBase: 2
            })
        );
    }

    function issue(address _holder, uint256 numShares) external {
        RewardLib.issue(_state, _holder, numShares);
    }

    function issueWithCurve(address _holder, uint256 numShares, uint8 curveId) external {
        RewardLib.issueWithCurve(_state, _holder, numShares, curveId);
    }

    function curve(uint8 id) external view returns (CurveParams memory params) {
        return _state.curves[id];
    }

    function holder(address _holder) external view returns (Holder memory) {
        return _state.holders[_holder];
    }

    function state() external view returns (PoolStatePartial memory) {
        return PoolStatePartial({totalShares: _state.totalShares, totalRewardIngress: _state.totalRewardIngress});
    }
}

contract RewardLibTest is BaseTest {
    RewardTestShim public shim = new RewardTestShim();

    function testIssuance() public {
        shim.issue(alice, 100_000);
        shim.issue(bob, 100_000);
        assertEq(shim.holder(alice).numShares, 100_000);
        assertEq(shim.holder(bob).numShares, 100_000);
        assertEq(shim.state().totalShares, 200_000);
    }

    function testIssuanceOnCurve() public {
        // state.curves[0] = defaults();
        uint256 multiplier = RewardCurveLib.currentMultiplier(shim.curve(0));
        shim.issueWithCurve(alice, 100_000, 0);
        shim.issueWithCurve(bob, 100_000, 0);
        assertEq(shim.holder(alice).numShares, 100_000 * multiplier);
        assertEq(shim.holder(bob).numShares, 100_000 * multiplier);
        assertEq(shim.state().totalShares, 200_000 * multiplier);
    }

    function testAllocation() public {
        // shim.allocate(alice, 100_000);
        // shim.allocate(bob, 100_000);
        // assertEq(shim.state().totalRewardIngress, 200_000);
    }
}
