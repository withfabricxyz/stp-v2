// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "../types/Constants.sol";

/// @dev Library for storing referral codes and their associated percentages
library ReferralLib {
    error ReferralLocked();

    /// @dev A referral code was created or updated
    event ReferralSet(uint256 indexed code);

    /// @dev A referral code was destroyed (set to 0)
    event ReferralDestroyed(uint256 indexed code);

    /// @dev Struct for holding details of a referral code
    struct Code {
        /// @dev The percentage of the transfer to give to the referrer
        uint16 basisPoints;
        /// @dev Whether this code can be updated once set (mutable or not)
        bool permanent;
        /// @dev A specific address (0x0 for any address)
        address referrer;
    }

    struct State {
        mapping(uint256 => Code) codes;
    }

    /// @dev Basic validation and storage for a referral code. A single call was used to reduce size
    function setReferral(State storage state, uint256 code, Code memory settings) internal {
        if (state.codes[code].permanent) revert ReferralLocked();
        if (settings.basisPoints == 0) {
            delete state.codes[code];
            emit ReferralDestroyed(code);
            return;
        }
        if (settings.basisPoints > MAX_REFERRAL_BPS) revert InvalidBasisPoints();

        state.codes[code] = settings;
        emit ReferralSet(code);
    }

    /// @dev Get bps for a referral code
    function getBps(State storage state, uint256 code, address referrer) internal view returns (uint16) {
        if (state.codes[code].referrer != address(0) && state.codes[code].referrer != referrer) return 0;
        return state.codes[code].basisPoints;
    }
}
