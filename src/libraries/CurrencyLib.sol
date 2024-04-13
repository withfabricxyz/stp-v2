// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

/// @dev A wrapper for the address type to represent a denomination (ERC20, Native)
type Currency is address;

/// @title CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library CurrencyLib {
    using CurrencyLib for Currency;
    using SafeTransferLib for address;

    /// @notice Thrown when a capture is invalid
    error InvalidCapture();

    /// @notice Thrown when an account is invalid
    error InvalidAccount();

    /// @notice Thrown when approval is invalid
    error InvalidApproval();

    /// @dev wrap 0 address as a native currency
    Currency public constant NATIVE = Currency.wrap(address(0));

    /// @dev capture native or ERC20 tokens
    function capture(Currency currency, address from, uint256 amount) internal returns (uint256 capturedAmount) {
        capturedAmount = amount;
        if (currency.isNative()) {
            if (msg.value != amount) revert InvalidCapture();
        } else {
            if (msg.value > 0) revert InvalidCapture();
            // Calculate the captured amount (in case of a token with a fee on transfer, etc.)
            uint256 preBalance = currency.balance();
            Currency.unwrap(currency).safeTransferFrom(from, address(this), amount);
            capturedAmount = currency.balance() - preBalance;
        }
    }

    /// @dev release native or ERC20 tokens
    function transfer(Currency currency, address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidAccount();
        if (currency.isNative()) to.safeTransferETH(amount);
        else Currency.unwrap(currency).safeTransfer(to, amount);
    }

    /// @dev show the balance of the contract
    function balance(Currency currency) internal view returns (uint256) {
        if (currency.isNative()) return address(this).balance;
        return Currency.unwrap(currency).balanceOf(address(this));
    }

    /// @dev approve an ERC20 token (note, this is intended for sending tokens to another contract in a single txn)
    function approve(Currency currency, address spender, uint256 amount) internal {
        if (currency.isNative()) revert InvalidApproval();
        Currency.unwrap(currency).safeApprove(spender, amount);
    }

    /// @dev is the currency the native token, eg: ETH
    function isNative(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(NATIVE);
    }
}
