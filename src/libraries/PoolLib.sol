// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Pool} from "../types/Index.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev The initialization parameters for a subscription token
library PoolLib {
    using SafeERC20 for IERC20;

    error InsufficientBalance(uint256 amountRequested, uint256 balance);
    error PurchaseAmountMustMatchValueSent(uint256 amount, uint256 valueSent);
    error NativeTokensNotAcceptedForERC20Subscriptions();
    error InsufficientBalanceOrAllowance(uint256 preBalance, uint256 allowance);
    error FailedToTransferEther(address to, uint256 amount);
    error InvalidZeroTransfer();

    function total(Pool storage pool) internal view returns (uint256) {
        return pool.tokensIn;
    }

    function balance(Pool storage pool) internal view returns (uint256) {
        return pool.tokensIn - pool.tokensOut;
    }

    function isERC20(Pool storage pool) internal view returns (bool) {
        return pool.tokenAddress != address(0);
    }

    function transferTo(Pool storage source, Pool storage destination, uint256 amount) internal {
        if (amount > balance(source)) {
            revert InsufficientBalance(amount, balance(source));
        }
        source.tokensOut += amount;
        destination.tokensIn += amount;
    }

    function liquidateTo(Pool storage pool, Pool storage destination) internal {
        uint256 amount = balance(pool);
        if (amount > 0) {
            transferTo(pool, destination, amount);
        }
    }

    /// @dev Transfer tokens into the contract, either native or ERC20
    function transferIn(Pool storage pool, address from, uint256 amount) internal returns (uint256) {
        if (amount == 0) {
            revert InvalidZeroTransfer();
        }

        if (!isERC20(pool)) {
            if (msg.value != amount) {
                revert PurchaseAmountMustMatchValueSent(amount, msg.value);
            }
            pool.tokensIn += amount;
            return amount;
        }

        IERC20 token = IERC20(pool.tokenAddress);

        // Note: We support tokens which take fees, but do not support rebasing tokens
        if (msg.value != 0) {
            revert NativeTokensNotAcceptedForERC20Subscriptions();
        }
        uint256 preBalance = token.balanceOf(from);
        uint256 allowance = token.allowance(from, address(this));

        if (preBalance < amount || allowance < amount) {
            revert InsufficientBalanceOrAllowance(preBalance, allowance);
        }
        token.safeTransferFrom(from, address(this), amount);
        uint256 postBalance = token.balanceOf(from);
        uint256 finalAmount = preBalance - postBalance;
        pool.tokensIn += finalAmount;
        return finalAmount;
    }

    /// @dev Transfer tokens out of the contract, either native or ERC20
    function transferOut(Pool storage pool, address to, uint256 amount) internal {
        if (amount == 0) {
            revert InvalidZeroTransfer();
        }

        if (amount > balance(pool)) {
            revert InsufficientBalance(amount, balance(pool));
        }

        pool.tokensOut += amount;
        if (isERC20(pool)) {
            IERC20(pool.tokenAddress).safeTransfer(to, amount);
        } else {
            (bool sent,) = payable(to).call{value: amount}("");
            if (!sent) {
                revert FailedToTransferEther(to, amount);
            }
        }
    }

    function reconcileBalance(Pool storage pool, uint256 expectedBalance) internal {
        uint256 checkedBalance = 0;
        if (isERC20(pool)) {
            checkedBalance = IERC20(pool.tokenAddress).balanceOf(address(this));
        } else {
            checkedBalance = address(this).balance;
        }
        if (checkedBalance > expectedBalance) {
            pool.tokensIn += checkedBalance - expectedBalance;
        }
    }
}
