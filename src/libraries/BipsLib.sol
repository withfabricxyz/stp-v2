// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @dev The initialization parameters for a subscription token
library BipsLib {
    /// @dev Maximum basis points (100%)
    uint16 private constant MAX_BIPS = 10_000;

    function computeBipsValue(uint16 self, uint256 amount) internal pure returns (uint256) {
        return (amount * self) / MAX_BIPS;
    }
}
