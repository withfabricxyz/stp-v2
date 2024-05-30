// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev The type of gate to use for a tier
enum GateType {
    NONE,
    ERC20,
    ERC721,
    ERC1155,
    STPV2
}

/// @notice A struct to represent a gate for a tier. A gate is metadata that is used to check if a subscriber
///         is eligible to join a tier.
///         The gate can be a contract that implements the IERC721/20 or IERC1155 interface, or
///         it can be the subscription token tier.
struct Gate {
    /// @dev The type of gate to use
    GateType gateType;
    /// @dev The address of the gate contract
    address contractAddress;
    /// @dev The id of the component to check for eligibility (for 1155 its the token id, for STP its the tier id)
    uint256 componentId;
    /// @dev The minimum balance required to join the tier
    uint256 balanceMin;
}

/// @notice A struct to represent tier configuration. Active subscribers belong to a tier, and each tier
///         has a set of constraints and properties to differentiate it from other tiers.
struct Tier {
    /// @dev The minimimum subscription time for the tier
    uint32 periodDurationSeconds;
    /// @dev The maximum number of subscribers the tier can have
    uint32 maxSupply;
    /// @dev The maximum number of future seconds a subscriber can hold (0 = unlimited)
    uint48 maxCommitmentSeconds;
    /// @dev The start timestamp for the tier (0 for deploy block time)
    uint48 startTimestamp;
    /// @dev The end timestamp for the tier (0 for never)
    uint48 endTimestamp;
    /// @dev The reward curve id to use
    uint8 rewardCurveId;
    /// @dev The reward bps
    uint16 rewardBasisPoints;
    /// @dev Whether the tier is paused (can subs mint or renew?)
    bool paused;
    /// @dev A flag to indicate if tokens can be transferred
    bool transferrable;
    /// @dev The initial mint price to join the tier
    uint256 initialMintPrice;
    /// @dev The price per period to renew the subscription (can be 0 for pay what you want tiers)
    uint256 pricePerPeriod;
    /// @dev The gate to use to check for subscription eligibility
    Gate gate;
}

/// @dev The fee configuration for a subscription contract (split between client and protocol)
struct FeeParams {
    /// @dev the protocol fee recipient
    address protocolRecipient;
    /// @dev the protocol fee in basis points
    uint16 protocolBps;
    /// @dev the client fee in basis points
    uint16 clientBps;
    /// @dev the client determined referral cut in basis points
    uint16 clientReferralBps;
    /// @dev the client fee recipient
    address clientRecipient;
}

/// @dev The initialization parameters for a subscription token
struct InitParams {
    /// @dev the name of the collection
    string name;
    /// @dev the symbol of the collection
    string symbol;
    /// @dev the metadata URI for the collection
    string contractUri;
    /// @dev the address of the owner of the contract (default admin)
    address owner;
    /// @dev the address of the token used for purchases (0x0 for native, otherwise erc20)
    address currencyAddress;
    /// @dev The initial global supply cap
    uint64 globalSupplyCap;
}

/// @dev The subscription struct which holds the state of a subscription for an account
struct Subscription {
    /// @dev The tier id of the subscription
    uint16 tierId;
    /// @dev The purchase timestamp of the subscription (for managing renewals/refunds)
    uint48 purchaseExpires;
    /// @dev The grant timestamp of the subscription (for managing grants/revokes)
    uint48 grantExpires;
    /// @dev The expiration timestamp of the subscription
    uint48 expiresAt;
    /// @dev The tokenId for the subscription
    uint64 tokenId;
}

/// @dev The advanced parameters for minting a subscription
struct MintParams {
    /// @dev The tier id of the subscription
    uint16 tierId;
    /// @dev The address of the recipient (token holder)
    address recipient;
    /// @dev The address of the referrer (reward recipient)
    address referrer;
    /// @dev The referral code
    uint256 referralCode;
    /// @dev The number of tokens being transferred
    uint256 purchaseValue;
}
