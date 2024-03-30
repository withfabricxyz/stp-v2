// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @dev Abstract contract for proxied contracts, which are not upgradeable.
abstract contract Proxied {
    error AlreadyInitialized();

    uint256 private _initialized;

    struct InitDataSlot {
        bool initialized;
    }

    // Copied from OpenZeppelin's Initializable contract
    bytes32 private constant SLOT = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function checkInit() internal view {
        if (_slot().initialized) {
            revert AlreadyInitialized();
        }
    }

    function _initialize() internal {
        _slot().initialized = true;
    }

    function _slot() internal pure returns (InitDataSlot storage pointer) {
        assembly {
            pointer.slot := SLOT
        }
    }
}
