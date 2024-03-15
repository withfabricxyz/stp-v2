// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {Tier, Gate} from "src/types/Index.sol";

contract TierTestShim {
    function mintPrice(Tier memory tier, uint256 numPeriods, bool firstMint) external pure returns (uint256) {
        return TierLib.mintPrice(tier, numPeriods, firstMint);
    }

    function hasSupply(Tier memory tier, uint32 numSubs) external pure returns (bool) {
        return TierLib.hasSupply(tier, numSubs);
    }

    function tokensPerSecond(Tier memory tier) external pure returns (uint256) {
        return TierLib.tokensPerSecond(tier);
    }
}

contract TierLibTest is Test {
    TierTestShim public shim = new TierTestShim();

    function defaults() internal pure returns (Tier memory) {
        Gate memory gate;
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
}
