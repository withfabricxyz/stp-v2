// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IRewardPool {
    event RewardsAllocated(uint256 finalAmount);
    event RewardTransfer(address indexed account, uint256 amount);

    error AccountNotStaked();
    error InsufficientRewards();

    /**
     * @notice Distribute rewards to all holders
     * @param numTokens The number of tokens to distribute (must match msg.value or have an approval for the token transfer)
     */
    // function allocateRewards(uint256 numTokens) external payable;

    /**
     * @notice Transfer reward balance for a given account. Requires the account to have all funds staked.
     * @param account The account to transfer rewards to
     */
    function transferRewardsFor(address account) external;

    // Requires authentication
    // function mint(address account, uint256 amount, uint256 payment) external payable;

    // function allocate(address account, uint256 amount, uint256 tokensIn) external;

    // function transferRewards(address account, uint256 amount) external;

    // function slashRewards(address account) external;

    // function rewardBalance(address account) external view returns (uint256);

    // function stakedBalance(address account) external view returns (uint256);
}
