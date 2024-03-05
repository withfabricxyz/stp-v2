// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Tier {
    uint32 periodDurationSeconds; // How long is a single period?
    uint32 maxSupply; // Adjustable 0=unlimited
    uint32 maxMintablePeriods; // Limit how many active periods a user can have (3 years MAX, 0 for unlimited)
    uint32 numSubs; // How many are currently minted
    uint32 numFrozenSubs; // How many are currently frozen
    uint16 id;
    uint8 rewardMultiplier; // disable rewards for free tier, etc
    bool paused; // if true, no new mints or adding time
    bool payWhatYouWant; // if true, pricePerPeriod is ignored and the user can get ONE period for this price (including 0)
    uint256 allowList; // Only allow certain people to mint
    uint256 initialMintPrice; // can be any amount, it's the cost to mint the NFT, and not inclusive of the period price??
    uint256 pricePerPeriod;
}
