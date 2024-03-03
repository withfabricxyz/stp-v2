// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Allocation} from "../types/Allocation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev The initialization parameters for a subscription token
library AllocationLib {
    using SafeERC20 for IERC20;

    error InsufficientBalance(uint256 amountRequested, uint256 balance);
    error PurchaseAmountMustMatchValueSent(uint256 amount, uint256 valueSent);
    error NativeTokensNotAcceptedForERC20Subscriptions();
    error InsufficientBalanceOrAllowance(uint256 preBalance, uint256 allowance);
    error FailedToTransferEther(address to, uint256 amount);

    function total(Allocation storage self) internal view returns (uint256) {
        return self.tokensIn;
    }

    function balance(Allocation storage self) internal view returns (uint256) {
        return self.tokensIn - self.tokensOut;
    }

    function isERC20(Allocation storage self) internal view returns (bool) {
        return self.tokenAddress != address(0);
    }

    function internalTransferTo(Allocation storage source, Allocation storage destination, uint256 amount) internal {
        if (amount > balance(source)) {
            revert InsufficientBalance(amount, balance(source));
        }
        source.tokensOut += amount;
        destination.tokensIn += amount;
    }

    /// @dev Transfer tokens into the contract, either native or ERC20
    function transferIn(Allocation storage self, address from, uint256 amount) internal returns (uint256) {
        if (!isERC20(self)) {
            if (msg.value != amount) {
                revert PurchaseAmountMustMatchValueSent(amount, msg.value);
            }
            self.tokensIn += amount;
            return amount;
        }

        IERC20 token = IERC20(self.tokenAddress);

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
        self.tokensIn += finalAmount;
        return finalAmount;
    }

    /// @dev Transfer tokens out of the contract, either native or ERC20
    function transferOut(Allocation storage self, address to, uint256 amount) internal {
        if (amount > balance(self)) {
            revert InsufficientBalance(amount, balance(self));
        }
        self.tokensOut += amount;
        if (isERC20(self)) {
            IERC20(self.tokenAddress).safeTransfer(to, amount);
        } else {
            (bool sent,) = payable(to).call{value: amount}("");
            if (!sent) {
                revert FailedToTransferEther(to, amount);
            }
        }
    }

    function reconcileBalance(Allocation storage self) internal {
        uint256 expectedBalance = balance(self);
        uint256 checkedBalance = 0;
        if (isERC20(self)) {
            checkedBalance = IERC20(self.tokenAddress).balanceOf(address(this));
        } else {
            checkedBalance = address(this).balance;
        }
        if (checkedBalance > expectedBalance) {
            self.tokensIn += checkedBalance - expectedBalance;
        }
    }
}
