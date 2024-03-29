// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

abstract contract Proxied {
    error AlreadyInitialized();

    bool private _initialized;

    function checkInit() internal view {
        if (_initialized) {
            revert AlreadyInitialized();
        }
    }

    function _initialize() internal {
        _initialized = true;
    }
}