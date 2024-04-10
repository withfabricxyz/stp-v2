// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;


import {Currency} from "../libraries/CurrencyLib.sol";

struct Holder {
  /// @dev The number of shares earned
  uint256 numShares;
  /// @dev The number of rewards withdrawn
  uint256 rewardsWithdrawn;
  /// @dev The timestamp at which point slashing is allowed (+ grace period)
  uint48 slashingPoint;
}

struct RewardPoolParams {
    /// @dev the address of the currency contract
    address currencyAddress;
    /// @dev the grace period of inactivity before a sub is slashable
    uint32 slashGracePeriod;
    /// @dev whether the pool is slashable
    bool slashable;
}

/// @dev The curve parameters for reward pool share issuance
struct CurveParams {
    /// @dev the unique id for the curve within the pool
    uint8 id;
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
}

struct RewardParams {
    /// @dev The address of the pool
    address poolAddress;
    /// @dev The number of tokens in the pool
    uint16 bips;
}

// TODO?
struct HolderKey {
  address tokenAddress;
  uint256 tokenId;
}

struct PoolState {
    uint256 totalShares;
    uint256 totalRewardEgress;
    uint256 totalRewardIngress;
    uint256 slashedWithdraws;
    Currency currency;
    mapping(address => Holder) holders;
    mapping(uint8 => CurveParams) curves;
}

struct IssueParams {
    /// @dev The address of the pool
    address holder;
    /// @dev The number of tokens in the pool
    uint256 numShares;
    /// @dev The number of shares to issue
    uint256 allocation;
    /// @dev The number of shares to issue
    uint48 slashingThreshold;
    /// @dev The number of shares to issue
    uint8 curveId;
}

//// Views ////

struct PoolDetailView {
    uint8 numCurves;
    address currencyAddress;
    uint256 totalShares;
    uint256 balance;
}

struct CurveDetailView {
    // uint8 id;
    uint256 currentMultiplier;
    uint48 flattenTimestamp;
}

struct HolderDetailView {
    uint256 numShares;
    uint256 rewardsWithdrawn;
    uint48 slashingPoint;
}

