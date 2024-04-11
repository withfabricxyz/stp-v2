// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {CurveParams} from "src/types/Rewards.sol";

import "../types/Constants.sol";

/// @dev Library for storing referral codes and their associated rewards
library ReferralLib {
    /// @dev A referral code was created or updated
    event ReferralSet(uint256 indexed code, uint16 basisPoints);

    /// @dev A referral code was destroyed (set to 0)
    event ReferralDestroyed(uint256 indexed code);

    struct State {
        mapping(uint256 => uint16) codes;
    }

    function setReferral(State storage state, uint256 code, uint16 basisPoints) internal {
        if (basisPoints == 0) {
            delete state.codes[code];
            emit ReferralDestroyed(code);
            return;
        }
        if (basisPoints > MAX_BPS) revert InvalidBasisPoints();

        state.codes[code] = basisPoints;
        emit ReferralSet(code, basisPoints);
    }

    function computeReferralReward(State storage state, uint256 code, uint256 amount) internal view returns (uint256) {
        return (amount * state.codes[code]) / MAX_BPS;
    }
}
