// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IRewardMintCalls {
    function checkBinding(address currency, uint16 revShareBps) external view returns (bool);

    function mint(address account, uint256 amount, uint256 payment) external payable;
}
