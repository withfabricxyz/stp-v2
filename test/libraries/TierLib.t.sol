// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

contract TierTestShim {
    TierLib.State state;
    TierLib.State state2;

    function validate(Tier memory tier) external view {
        TierLib.validate(tier);
    }

    function checkJoin(Tier memory tier, uint32 subCount, address account, uint256 numTokens) external {
        state = TierLib.State({id: 1, subCount: subCount, params: tier});

        TierLib.checkJoin(state, account, numTokens);
    }

    function checkRenewal(Tier memory tier, Subscription memory sub, uint256 numTokens) external {
        state = TierLib.State({id: 1, subCount: 0, params: tier});
        TierLib.checkRenewal(state, sub, numTokens);
    }

    function computeSwitchTimeValue(
        Tier memory toTier,
        Tier memory fromTier,
        uint48 numSeconds
    ) external returns (uint48) {
        state = TierLib.State({id: 1, subCount: 0, params: toTier});
        state2 = TierLib.State({id: 2, subCount: 0, params: fromTier});
        return TierLib.computeSwitchTimeValue(state, state2, numSeconds);
    }

    function test() public {}
}

contract TierLibTest is Test {
    address internal alice = 0xb4c79DAB8f259c7Aee6E5b2aa729821864227E81;

    TierTestShim public shim = new TierTestShim();

    function defaults() internal pure returns (Tier memory) {
        Gate memory gate = Gate({gateType: GateType.NONE, contractAddress: address(0), componentId: 0, balanceMin: 1});

        return Tier({
            periodDurationSeconds: 2_592_000,
            paused: false,
            transferrable: true,
            maxSupply: 1000,
            rewardCurveId: 0,
            rewardBasisPoints: 0,
            initialMintPrice: 0.01 ether,
            pricePerPeriod: 0.005 ether,
            maxCommitmentSeconds: 24 * 2_592_000,
            startTimestamp: 0,
            endTimestamp: 0,
            gate: gate
        });
    }

    function testValidation() public {
        Tier memory tier = defaults();
        shim.validate(tier);

        tier.periodDurationSeconds = 0;
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidDuration.selector));
        shim.validate(tier);

        tier = defaults();
        tier.endTimestamp = uint48(block.timestamp + 1);
        shim.validate(tier);

        vm.warp(block.timestamp + 2);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierTimingInvalid.selector));
        shim.validate(tier);

        tier.startTimestamp = uint48(block.timestamp + 5);
        vm.warp(block.timestamp + 100);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierTimingInvalid.selector));
        shim.validate(tier);

        tier = defaults();
        tier.rewardBasisPoints = 10_001;
        vm.expectRevert(abi.encodeWithSelector(InvalidBasisPoints.selector));
        shim.validate(tier);
    }

    function testJoinChecks() public {
        Tier memory tier = defaults();

        // All good
        shim.checkJoin(tier, 0, alice, 1e18);

        // Max supply
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierHasNoSupply.selector, 1));
        shim.checkJoin(tier, 1000, alice, 1e18);

        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidMintPrice.selector, 0.01 ether));
        shim.checkJoin(tier, 1, alice, 0.009 ether);

        // Ensure gating is wired up
        TestERC20Token token = new TestERC20Token("FIAT", "FIAT", 18);
        tier.gate = Gate({gateType: GateType.ERC20, contractAddress: address(token), componentId: 0, balanceMin: 1});
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateCheckFailure.selector));
        shim.checkJoin(tier, 1, alice, 0.01 ether);

        tier = defaults();
        tier.startTimestamp = uint48(block.timestamp + 100);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierNotStarted.selector));
        shim.checkJoin(tier, 0, alice, 1e18);
    }

    function testRenewChecks() public {
        Tier memory tier = defaults();

        Subscription memory sub =
            Subscription({tokenId: 1, tierId: 1, purchaseExpires: 0, grantExpires: 0, expiresAt: 0});

        // All good
        shim.checkRenewal(tier, sub, 0.005 ether);

        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidRenewalPrice.selector, tier.pricePerPeriod));
        shim.checkRenewal(tier, sub, 0);

        tier.paused = true;
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierRenewalsPaused.selector));
        shim.checkRenewal(tier, sub, 0.05 ether);

        tier = defaults();
        tier.maxCommitmentSeconds = tier.periodDurationSeconds;
        vm.expectRevert(abi.encodeWithSelector(TierLib.MaxCommitmentExceeded.selector));
        shim.checkRenewal(tier, sub, tier.pricePerPeriod * 2);

        tier = defaults();
        tier.endTimestamp = uint48(block.timestamp + 2 * tier.periodDurationSeconds);
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierEndExceeded.selector));
        shim.checkRenewal(tier, sub, tier.pricePerPeriod * 3);
    }

    function testTimeRatios() public {
        Tier memory toTier = defaults();
        toTier.periodDurationSeconds = 30 days;
        toTier.pricePerPeriod = 0.02 ether;

        Tier memory fromTier = defaults();
        fromTier.pricePerPeriod = 0.01 ether;
        fromTier.periodDurationSeconds = 30 days;

        uint48 numSeconds = shim.computeSwitchTimeValue(toTier, fromTier, 30 days);
        assertApproxEqAbs(numSeconds, 15 days, 1);
        numSeconds = shim.computeSwitchTimeValue(fromTier, toTier, numSeconds);
        numSeconds = shim.computeSwitchTimeValue(toTier, fromTier, numSeconds);
        numSeconds = shim.computeSwitchTimeValue(fromTier, toTier, numSeconds);
        numSeconds = shim.computeSwitchTimeValue(toTier, fromTier, numSeconds);
        numSeconds = shim.computeSwitchTimeValue(fromTier, toTier, numSeconds);
        assertApproxEqAbs(numSeconds, 30 days, 10);
        assertTrue(numSeconds < 30 days);
    }
}
