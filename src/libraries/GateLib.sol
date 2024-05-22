// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";

import {Gate, GateType} from "../types/Index.sol";

/// @dev External hybrid interface for token gate checks
interface ExternalGate {
    function balanceOf(address account) external view returns (uint256);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function tierBalanceOf(uint16 tierId, address account) external view returns (uint256);
}

/// @notice Library for token gating tiers
library GateLib {
    using GateLib for Gate;
    using SafeCastLib for uint256;

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
    function validate(Gate memory gate) internal pure {
        if (gate.gateType != GateType.NONE) {
            if (gate.contractAddress == address(0)) revert GateInvalid();
            if (gate.balanceMin == 0) revert GateInvalid();
        }

        // STPV2 requires a tier component id (otherwise use 721)
        if (gate.gateType == GateType.STPV2 && (gate.componentId >= 2 ** 16 || gate.componentId == 0)) {
            revert GateInvalid();
        }
    }

    /// @dev Check if the account meets the gate requirements and revert if not
    function checkAccount(Gate memory gate, address account) internal view {
        if (gate.gateType == GateType.NONE) return;
        if (gate.balanceOf(account) < gate.balanceMin) revert GateCheckFailure();
    }

    /// @dev Get the balance of the account for the gate
    function balanceOf(Gate memory gate, address account) internal view returns (uint256 balance) {
        ExternalGate eg = ExternalGate(gate.contractAddress);
        if (gate.gateType == GateType.ERC721 || gate.gateType == GateType.ERC20) balance = eg.balanceOf(account);
        else if (gate.gateType == GateType.ERC1155) balance = eg.balanceOf(account, gate.componentId);
        else if (gate.gateType == GateType.STPV2) balance = eg.tierBalanceOf(gate.componentId.toUint16(), account);
        else balance = 0;
    }
}
