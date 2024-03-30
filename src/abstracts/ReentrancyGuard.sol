// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @dev A modifier that prevents reentrancy attacks
abstract contract ReentrancyGuard {
    error ReentrantCallError();

    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        if (locked == 2) {
            revert ReentrantCallError();
        }
        locked = 2;
        _;
        locked = 1;
    }
}
