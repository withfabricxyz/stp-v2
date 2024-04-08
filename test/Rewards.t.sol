// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TestImports.t.sol";

contract RewardsTest is BaseTest {
    RewardPool pool;

    function setUp() public {
        pool = new RewardPool();
        vm.store(
            address(pool),
            bytes32(uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132)),
            bytes32(0)
        );

        pool.initialize(defaultPoolParams(), defaultCurveParams());
        pool.setRoles(address(this), 0xff); // allow admin mint

        rewardParams.poolAddress = address(pool);
        rewardParams.bips = 5000;
        stp = reinitStp();

        pool.setRoles(address(stp), 1); // allow minter role to STP

        deal(alice, 1e19);
    }

    function testRewardTransfer() public {
        mint(alice, 0.0001 ether);
        mint(alice, 0.0001 ether);
        uint256 balance = pool.rewardBalanceOf(alice);
        assertEq(balance, 0.0001 ether);
    }
}
