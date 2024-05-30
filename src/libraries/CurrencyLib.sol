// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

/// @dev A wrapper for the address type to represent a denomination (ERC20, Native)
type Currency is address;

/// @title CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens (inspired by uniswap v4)
library CurrencyLib {
    using CurrencyLib for Currency;
    using SafeTransferLib for address;

    /// @notice Thrown when a capture is invalid
    error InvalidCapture();

    /// @notice Thrown when an account is invalid
    error InvalidAccount();

    /// @dev capture native or ERC20 tokens
    function capture(Currency currency, uint256 amount) internal returns (uint256 capturedAmount) {
        capturedAmount = amount;
        if (currency.isNative()) {
            if (msg.value != amount) revert InvalidCapture();
        } else {
            if (msg.value > 0) revert InvalidCapture();
            // Calculate the captured amount (in case of a token with a fee on transfer, etc.)
            uint256 preBalance = currency.balance();
            Currency.unwrap(currency).safeTransferFrom(msg.sender, address(this), amount);
            capturedAmount = currency.balance() - preBalance;
        }
    }

    /// @dev release native or ERC20 tokens
    function transfer(Currency currency, address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidAccount();
        if (currency.isNative()) to.safeTransferETH(amount);
        else Currency.unwrap(currency).safeTransfer(to, amount);
    }

    /// @dev attempt to transfer native or ERC20 tokens to recipient, returning success rather than reverting
    function tryTransfer(Currency currency, address to, uint256 amount) internal returns (bool success) {
        if (to == address(0)) revert InvalidAccount();
        if (currency.isNative()) {
            success = to.trySafeTransferETH(amount, SafeTransferLib.GAS_STIPEND_NO_GRIEF);
        } else {
            address token = Currency.unwrap(currency);
            /// @solidity memory-safe-assembly
            assembly {
                mstore(0x14, to) // Store the `to` argument.
                mstore(0x34, amount) // Store the `amount` argument.
                mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
                // Perform the transfer, returning success or failure
                success :=
                    and( // The arguments of `and` are evaluated from right to left.
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
            }
        }
    }

    /// @dev show the balance of the contract
    function balance(Currency currency) internal view returns (uint256) {
        if (currency.isNative()) return address(this).balance;
        return Currency.unwrap(currency).balanceOf(address(this));
    }

    /// @dev is the currency the native token, eg: ETH (0x0 address indicates such)
    function isNative(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == address(0);
    }
}
