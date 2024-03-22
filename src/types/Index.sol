// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @dev The type of gate to use for a tier
enum GateType {
    ERC20,
    ERC721,
    ERC1155,
    STPV2,
    NONE
}

/// @title Gate
/// @notice A struct to represent a gate for a tier. A gate is metadata that is used to check if a subscriber
/// is eligible to join a tier. The gate can be a contract that implements the IERC721/20 or IERC1155 interface, or
/// it can be the subscription token itself.
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
    /// @dev The maximum number of future seconds a subscriber can hold (0 = unlimited)
    uint48 maxCommitmentSeconds;
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
    Gate gate;
}

// TODO: Start date for tier
// TODO: End date for tier

struct FeeParams {
    /// @dev the address which receives fees
    address collector;
    /// @dev the fee in basis points
    uint16 bips;
}

/// @dev The initialization/config parameters for rewards
struct RewardParams {
    /// @dev the reward amount in basis points
    uint16 bips;
    /// @dev the number of periods for which rewards are paid (acts as the exponent)
    uint8 numPeriods;
    /// @dev The base of the exponential formula for reward calculations
    uint8 formulaBase;
    /// @dev the period duration in seconds
    uint48 periodSeconds;
    /// @dev the start timestamp for rewards
    uint48 startTimestamp;
    /// @dev the minimum multiplier for rewards
    uint8 minMultiplier;
    /// @dev a flag to indicate if rewards are slashable
    bool slashable;
    /// @dev the grace period of inactivity before a sub is slashable
    uint32 slashGracePeriod;
}

/// @dev The initialization parameters for a subscription token
struct InitParams {
    /// @dev the name of the collection
    string name;
    /// @dev the symbol of the collection
    string symbol;
    /// @dev the metadata URI for the collection
    string contractUri;
    /// @dev the metadata URI for the tokens
    string tokenUri;
    /// @dev the address of the owner of the contract (default admin)
    address owner;
    /// @dev the address of the ERC20 token used for purchases, or the 0x0 for native
    address erc20TokenAddr;
}

struct DeployParams {
    /// @dev the fee configuration id to use for this deployment
    uint256 feeConfigId;
    /// @dev the init parameters for the collection
    InitParams initParams;
    /// @dev the init parameters for the default tier (tier 1)
    Tier tierParams;
    /// @dev the reward parameters for the collection
    RewardParams rewardParams;
}

/// @dev The subscription struct which holds the state of a subscription for an account
struct Subscription {
    /// @dev The tokenId for the subscription
    uint256 tokenId;
    /// @dev The number of tokens transferred
    uint256 totalPurchased;
    /// @dev The number of seconds purchased
    uint256 secondsPurchased;
    /// @dev The number of seconds granted by the creator
    uint256 secondsGranted;
    /// @dev A time offset used to adjust expiration for grants
    uint256 grantOffset;
    /// @dev A time offset used to adjust expiration for purchases
    uint256 purchaseOffset;
    /// @dev The number of reward points earned
    uint256 rewardPoints;
    /// @dev The number of rewards withdrawn
    uint256 rewardsWithdrawn;
    /// @dev The tier id of the subscription
    uint16 tierId;
}

/// @dev The pool struct which holds the state of a given pool for a token
struct Pool {
    /// @dev The number of tokens that have come into the pool
    uint256 tokensIn;
    /// @dev The number of tokens that have left the pool
    uint256 tokensOut;
    /// @dev The ERC20 token address (or 0x0 for native)
    address tokenAddress;
}
