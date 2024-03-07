// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RewardParams} from "src/types/InitParams.sol";

library RewardLib {
    function passedHalvings(RewardParams memory self) internal view returns (uint256) {
        return (block.timestamp - self.startTimestamp) / self.rewardPeriodSeconds;
    }

    function currentMultiplier(RewardParams memory self) internal view returns (uint256 multiplier) {
        if (self.numRewardHalvings == 0) {
            return 0;
        }
        uint256 halvings = passedHalvings(self);
        if (halvings > self.numRewardHalvings) {
            return 0;
        }
        return (2 ** self.numRewardHalvings) / (2 ** halvings);
    }
}
