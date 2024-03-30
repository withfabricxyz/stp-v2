// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IRewardPool {
    event RewardsAllocated(uint256 finalAmount);
    event RewardTransfer(address indexed account, uint256 amount);

    error UnstakedAccess();
    error InsufficientRewards();

    function distributeRewards(uint256 numTokens) external payable;

    function transferRewards(address account) external;
    // function allocate(address account, uint256 amount, uint256 tokensIn) external;

    // function transferRewards(address account, uint256 amount) external;

    // function slashRewards(address account) external;

    // function rewardBalance(address account) external view returns (uint256);

    // function stakedBalance(address account) external view returns (uint256);
}
