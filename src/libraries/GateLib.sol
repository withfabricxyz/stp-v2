// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Gate, GateType} from "../types/Index.sol";

interface ExternalGate {
  function balanceOf(address account) external view returns (uint256);
  function balanceOf(address account, uint256 id) external view returns (uint256);
  function tierBalanceOf(address account, uint16 tierId) external view returns (uint256);
}

library GateLib {
    /////////////////////
    // ERRORS
    /////////////////////

    error GateCheckFailure();

    function validate(Gate memory gate) internal pure returns (Gate memory) {
        return gate; // TODO
    }

    function checkAccount(Gate memory gate, address account) internal view {
      if(gate.gateType == GateType.NONE) {
        return;
      }

      uint256 balance = balanceOf(gate, account);
      if(balance < gate.balanceMin) {
        revert GateCheckFailure();
      }
    }

    function balanceOf(Gate memory gate, address account) internal view returns (uint256) {
      ExternalGate eg = ExternalGate(gate.contractAddress);
      if(gate.gateType == GateType.ERC20 || gate.gateType == GateType.ERC721) {
        return eg.balanceOf(account);
      } else if(gate.gateType == GateType.STPV2) {
        if(gate.componentId > 0) {
          return eg.tierBalanceOf(account, uint16(gate.componentId));
        }
        return eg.balanceOf(account);
      } else if(gate.gateType == GateType.ERC1155) {
        return eg.balanceOf(account, gate.componentId);
      }

      return 0;
    }
}
