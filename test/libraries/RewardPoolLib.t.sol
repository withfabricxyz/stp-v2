// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

struct PoolStatePartial {
    uint256 totalShares;
    uint256 totalRewardIngress;
}

// We need to create a shim contract to call the internal functions of RewardPoolLib in order to get
// foundry to generate the coverage report correctly
contract RewardTestShim {
    using RewardPoolLib for RewardPoolLib.State;

    RewardPoolLib.State private _state;

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

    function createCurve(CurveParams memory _curve) external {
        RewardPoolLib.createCurve(_state, _curve);
    }

    function issue(address _holder, uint256 numShares) external {
        RewardPoolLib.issue(_state, _holder, numShares);
    }

    function issueWithCurve(address _holder, uint256 numShares, uint8 curveId) external {
        RewardPoolLib.issueWithCurve(_state, _holder, numShares, curveId);
    }

    function allocate(uint256 amount) external {
        RewardPoolLib.allocate(_state, amount);
    }

    function claimRewards(address account) external returns (uint256 amount) {
        return RewardPoolLib.claimRewards(_state, account);
    }

    function curve(uint8 id) external view returns (CurveParams memory params) {
        return _state.curves[id];
    }

    function holder(address _holder) external view returns (Holder memory) {
        return _state.holders[_holder];
    }

    function rewardBalanceOf(address account) external view returns (uint256) {
        return RewardPoolLib.rewardBalanceOf(_state, account);
    }

    function balance() external view returns (uint256) {
        return RewardPoolLib.balance(_state);
    }

    function burn(address account) external {
        RewardPoolLib.burn(_state, account);
    }

    function state() external view returns (PoolStatePartial memory) {
        return PoolStatePartial({totalShares: _state.totalShares, totalRewardIngress: _state.totalRewardIngress});
    }

    function test() public {}
}

contract RewardPoolLibTest is BaseTest {
    RewardTestShim public shim = new RewardTestShim();

    function testCurve() public {
        vm.expectEmit(true, true, false, true, address(shim));
        emit RewardPoolLib.CurveCreated(1);
        shim.createCurve(
            CurveParams({
                numPeriods: 6,
                periodSeconds: 86_400,
                startTimestamp: uint48(block.timestamp),
                minMultiplier: 0,
                formulaBase: 2
            })
        );
    }

    function testIssuance() public {
        vm.expectEmit(true, true, false, true, address(shim));
        emit RewardPoolLib.SharesIssued(alice, 100_000);
        shim.issue(alice, 100_000);
        shim.issue(bob, 100_000);
        assertEq(shim.holder(alice).numShares, 100_000);
        assertEq(shim.holder(bob).numShares, 100_000);
        assertEq(shim.state().totalShares, 200_000);
    }

    function testIssuanceOnCurve() public {
        // state.curves[0] = defaults();
        uint256 multiplier = RewardCurveLib.currentMultiplier(shim.curve(0));
        vm.expectEmit(true, true, false, true, address(shim));
        emit RewardPoolLib.SharesIssued(alice, 100_000 * multiplier);
        shim.issueWithCurve(alice, 100_000, 0);
        shim.issueWithCurve(bob, 100_000, 0);
        assertEq(shim.holder(alice).numShares, 100_000 * multiplier);
        assertEq(shim.holder(bob).numShares, 100_000 * multiplier);
        assertEq(shim.state().totalShares, 200_000 * multiplier);
    }

    function testAllocation() public {
        vm.expectRevert(RewardPoolLib.AllocationWithoutShares.selector);
        shim.allocate(100_000);

        shim.issue(alice, 100_000);

        vm.expectEmit(true, true, false, true, address(shim));
        emit RewardPoolLib.RewardsAllocated(100_000);
        shim.allocate(100_000);
        assertEq(shim.state().totalRewardIngress, 100_000);
        assertEq(shim.rewardBalanceOf(alice), 100_000);
    }

    function testClaim() public {
        assertEq(0, shim.rewardBalanceOf(alice));
        shim.issue(alice, 100_000);

        vm.expectRevert(RewardPoolLib.NoRewardsToClaim.selector);
        shim.claimRewards(alice);
        assertEq(0, shim.rewardBalanceOf(alice));

        shim.allocate(100_000);
        assertEq(shim.state().totalRewardIngress, 100_000);
        assertEq(shim.rewardBalanceOf(alice), 100_000);

        vm.expectEmit(true, true, false, true, address(shim));
        emit RewardPoolLib.RewardsClaimed(alice, 100_000);
        shim.claimRewards(alice);
        assertEq(shim.rewardBalanceOf(alice), 0);
        assertEq(shim.balance(), 0);
    }

    function testBurn() public {
        vm.expectRevert(RewardPoolLib.NoSharesToBurn.selector);
        shim.burn(alice);

        shim.issue(alice, 100_000);
        shim.issue(bob, 100_000);
        shim.allocate(100_000);

        assertEq(shim.rewardBalanceOf(bob), 50_000);

        vm.expectEmit(true, true, false, true, address(shim));
        emit RewardPoolLib.SharesBurned(alice, 100_000);
        shim.burn(alice);
        assertEq(shim.state().totalShares, 100_000);
        assertEq(shim.rewardBalanceOf(alice), 0);
        assertEq(shim.rewardBalanceOf(bob), 100_000);

        shim.burn(bob);
        assertEq(shim.state().totalShares, 0);
    }
}