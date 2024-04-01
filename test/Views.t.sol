// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract ViewsTest is BaseTest {
    function setUp() public {
        reinitStp();
    }

    function testTierDetails() public {
        Tier memory tier = stp.tierDetails(1);
        assertEq(1, tier.id);
    }

    function testTierCount() public prank(creator) {
        Tier memory tier = tierParams;
        assertEq(1, stp.tierCount());
        tier.id = 2;
        stp.createTier(tier);
        assertEq(2, stp.tierCount());
    }

    function testTierSupply() public prank(creator) {
        (uint256 supply, uint256 sold) = stp.tierSupply(1);
        assertEq(0, supply);
        assertEq(0, sold);
    }
}
