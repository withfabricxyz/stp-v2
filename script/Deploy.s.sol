// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/SubscriptionTokenV2.sol";
import "src/RewardPool.sol";
import "src/STPV2Factory.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        SubscriptionTokenV2 stp = new SubscriptionTokenV2();
        RewardPool pool = new RewardPool();
        STPV2Factory factory = new STPV2Factory(address(stp), address(pool));

        vm.stopBroadcast();
    }
}
