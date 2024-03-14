// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

enum TierGateType {
    ERC20,
    ERC721,
    ERC1155,
    STPV2,
    NONE
}

/// @title TierGate
/// @notice A struct to represent a gate for a tier. A gate is a contract that is used to check if a subscriber
/// is eligible to join a tier. The gate can be a contract that implements the IERC721 or IERC1155 interface, or
/// it can be the subscription token itself.
struct TierGate {
    /// @dev The type of gate to use
    TierGateType gateType;
    /// @dev The address of the gate contract
    address contractAddress;
    /// @dev The id of the component to check for eligibility (for 1155 its the token id, for STP its the tier id)
    uint256 componentId;
    /// @dev The minimum balance required to join the tier
    uint256 balanceMin;
}

/// @title Tier
/// @notice A struct to represent tier configuration. Active subscribers belong to a tier, and each tier
/// has a set of constraints and properties to differentiate it from other tiers.
struct Tier {
    /// @dev The id of the tier
    uint16 id;
    /// @dev The minimimum subscription time for the tier
    uint32 periodDurationSeconds;
    /// @dev The maximum number of subscribers the tier can have (0 = unlimited)
    uint32 maxSupply;
    /// @dev The maximum number of future periods a subscriber can subscribe for
    uint32 maxMintablePeriods;
    /// @dev The secondary reward multiplier for the tier (0 to disable rewards for the tier)
    uint8 rewardMultiplier;
    /// @dev Whether the tier is paused (can subs mint or renew?)
    bool paused;
    /// @dev A flag to indicate if tokens can be transferred
    bool transferrable;
    /// @dev The initial mint price to join the tier
    uint256 initialMintPrice;
    /// @dev The price per period to renew the subscription (can be 0 for pay what you want tiers)
    uint256 pricePerPeriod;
    /// @dev The gate to use to check for subscription eligibility
    TierGate gate;
}
