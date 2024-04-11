// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

/// @dev A wrapper for the address type to represent a denomination (ERC20, Native)
type Currency is address;

using {greaterThan as >, lessThan as <, greaterThanOrEqualTo as >=, equals as ==} for Currency global;

function equals(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) == Currency.unwrap(other);
}

function greaterThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) > Currency.unwrap(other);
}

function lessThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) < Currency.unwrap(other);
}

function greaterThanOrEqualTo(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) >= Currency.unwrap(other);
}

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
            // Note: We support tokens which take fees, but do not support rebasing tokens
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
        return currency.balanceOf(address(this));
    }

    /// @dev show the balance of an account
    function balanceOf(Currency currency, address owner) internal view returns (uint256) {
        if (currency.isNative()) return owner.balance;
        else return Currency.unwrap(currency).balanceOf(owner);
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
