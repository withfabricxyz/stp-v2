// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {Tier} from "src/types/Tier.sol";

contract TierLibTest is Test {
    using TierLib for Tier;

    Tier tier;

    function setUp() public {
        tier = Tier({
            id: 1,
            periodDurationSeconds: 2592000,
            paused: false,
            payWhatYouWant: false,
            maxSupply: 0,
            numSubs: 0,
            numFrozenSubs: 0,
            rewardMultiplier: 0,
            allowList: 0,
            initialMintPrice: 0.01 ether,
            pricePerPeriod: 0.005 ether,
            maxMintablePeriods: 24
        });
    }

    function testPrice() public {
        assertEq(tier.mintPrice(1, false), 0.005 ether);
        assertEq(tier.mintPrice(12, false), 0.005 * 12 ether);
        assertEq(tier.mintPrice(12, true), 0.005 * 12 ether + 0.01 ether);
    }
}
