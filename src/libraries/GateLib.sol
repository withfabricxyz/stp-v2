// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Gate, GateType} from "../types/Index.sol";

interface ExternalGate {
    function balanceOf(address account) external view returns (uint256);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function tierBalanceOf(uint16 tierId, address account) external view returns (uint256);
}

/// @title GateLib
/// @notice Library for token gating tiers
library GateLib {
    /////////////////////
    // ERRORS
    /////////////////////

    /// @dev The account does not meet the gate requirements
    error GateCheckFailure();

    /// @dev The gate configuration is invalid
    error GateInvalid();

    /////////////////////
    // FUNCTIONS
    /////////////////////

    /// @dev Validate the gate configuration
    function validate(Gate memory gate) internal pure returns (Gate memory) {
        if (gate.gateType != GateType.NONE) {
            if (gate.contractAddress == address(0)) {
                revert GateInvalid();
            }
            if (gate.balanceMin == 0) {
                revert GateInvalid();
            }
        }

        if (gate.gateType == GateType.STPV2 && gate.componentId >= 2 ** 16) {
            revert GateInvalid();
        }

        return gate;
    }

    /// @dev Check if the account meets the gate requirements and revert if not
    function checkAccount(Gate memory gate, address account) internal view {
        if (gate.gateType == GateType.NONE) {
            return;
        }

        uint256 balance = balanceOf(gate, account);
        if (balance < gate.balanceMin) {
            revert GateCheckFailure();
        }
    }

    /// @dev Get the balance of the account for the gate
    function balanceOf(Gate memory gate, address account) internal view returns (uint256) {
        ExternalGate eg = ExternalGate(gate.contractAddress);

        if (gate.gateType == GateType.ERC20 || gate.gateType == GateType.ERC721) {
            return eg.balanceOf(account);
        }

        if (gate.gateType == GateType.STPV2) {
            if (gate.componentId > 0) {
                return eg.tierBalanceOf(uint16(gate.componentId), account);
            }
            return eg.balanceOf(account);
        }

        if (gate.gateType == GateType.ERC1155) {
            return eg.balanceOf(account, gate.componentId);
        }

        return 0;
    }
}
