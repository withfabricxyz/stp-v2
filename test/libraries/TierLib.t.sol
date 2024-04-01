// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

contract TierTestShim {
    function validate(Tier memory tier) external view {
        TierLib.validate(tier);
    }

    function mintPrice(Tier memory tier, uint256 numPeriods, bool firstMint) external pure returns (uint256) {
        return TierLib.mintPrice(tier, numPeriods, firstMint);
    }

    function checkJoin(Tier memory tier, uint32 subCount, address account, uint256 numTokens) external view {
        TierLib.checkJoin(tier, subCount, account, numTokens);
    }

    function checkRenewal(Tier memory tier, Subscription memory sub, uint256 numTokens) external view {
        TierLib.checkRenewal(tier, sub, numTokens);
    }
}

contract TierLibTest is Test {
    address internal alice = 0xb4c79DAB8f259c7Aee6E5b2aa729821864227E81;

    TierTestShim public shim = new TierTestShim();

    function defaults() internal pure returns (Tier memory) {
        Gate memory gate = Gate({gateType: GateType.NONE, contractAddress: address(0), componentId: 0, balanceMin: 1});

        return Tier({
            id: 1,
            periodDurationSeconds: 2592000,
            paused: false,
            transferrable: true,
            maxSupply: 0,
            rewardMultiplier: 0,
            initialMintPrice: 0.01 ether,
            pricePerPeriod: 0.005 ether,
            maxCommitmentSeconds: 24 * 2592000,
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
        tier.gate.gateType = GateType.STPV2;
        tier.gate.componentId = tier.id;
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateInvalid.selector));
        shim.validate(tier);

        tier.gate.contractAddress = address(shim);
        vm.expectRevert(abi.encodeWithSelector(GateLib.GateInvalid.selector));
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
    }

    function testPrice() public {
        Tier memory tier = defaults();
        assertEq(shim.mintPrice(tier, 1, false), 0.005 ether);
        assertEq(shim.mintPrice(tier, 12, false), 0.005 * 12 ether);
        assertEq(shim.mintPrice(tier, 12, true), 0.005 * 12 ether + 0.01 ether);
    }

    function testFreeMint() public {
        Tier memory tier = defaults();
        tier.pricePerPeriod = 0;
        tier.initialMintPrice = 0;
        assertEq(shim.mintPrice(tier, 1, false), 0);
        assertEq(shim.mintPrice(tier, 12, false), 0);
        assertEq(shim.mintPrice(tier, 12, true), 0);
    }

    function testJoinChecks() public {
        Tier memory tier = defaults();

        // All good
        shim.checkJoin(tier, 0, alice, 1e18);

        tier.maxSupply = 1000;
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

        Subscription memory sub = Subscription({
            tokenId: 1,
            tierId: 1,
            purchaseOffset: 0,
            secondsPurchased: 0,
            totalPurchased: 0,
            grantOffset: 0,
            secondsGranted: 0
        });

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
}
