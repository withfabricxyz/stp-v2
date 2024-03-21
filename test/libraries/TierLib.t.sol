// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {GateLib} from "src/libraries/GateLib.sol";
import {Tier, Gate, GateType, Subscription} from "src/types/Index.sol";
import {TestERC20Token} from "../TestHelpers.t.sol";

contract TierTestShim {
    function mintPrice(Tier memory tier, uint256 numPeriods, bool firstMint) external pure returns (uint256) {
        return TierLib.mintPrice(tier, numPeriods, firstMint);
    }

    function checkJoin(Tier memory tier, uint32 subCount, address account, uint256 numTokens) external view {
        TierLib.checkJoin(tier, subCount, account, numTokens);
    }

    function checkRenewal(Tier memory tier, Subscription memory sub, uint256 numTokens) external pure {
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
            maxMintablePeriods: 24,
            gate: gate
        });
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
            secondsGranted: 0,
            rewardPoints: 0,
            rewardsWithdrawn: 0
        });

        // All good
        shim.checkRenewal(tier, sub, 0.005 ether);

        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidRenewalPrice.selector, tier.pricePerPeriod));
        shim.checkRenewal(tier, sub, 0);

        tier.paused = true;
        vm.expectRevert(abi.encodeWithSelector(TierLib.TierRenewalsPaused.selector));
        shim.checkRenewal(tier, sub, 0.05 ether);
    }
}
