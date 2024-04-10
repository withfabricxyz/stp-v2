// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Currency, CurrencyLib} from "../libraries/CurrencyLib.sol";

contract TokenRecovery  {
    using CurrencyLib for Currency;


    error InvalidRecovery();

    /**
     * @dev Check whether the token can be recovered (revert to prevent a recovery)
     * @param tokenAddress the address of the token to check
     */
    function _checkRecovery(address tokenAddress) internal virtual view {
    }

    /**
     * @notice Recover a token from the contract (with a check to prevent recovering a contract dependency)
     * @param tokenAddress the address of the token to recover
     * @param recipientAddress the address to send the tokens to
     * @param tokenAmount the amount of tokens to send
     */
    function recoveryCurrency(address tokenAddress, address recipientAddress, uint256 tokenAmount) external {
        _checkRecovery(tokenAddress);
        Currency.wrap(tokenAddress).transfer(recipientAddress, tokenAmount);
    }
}
