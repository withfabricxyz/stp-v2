// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {
    InitParams,
    Subscription,
    RewardPoolParams,
    Tier,
    Subscription,
    Gate,
    GateType,
    DeployParams
} from "src/types/Index.sol";
import {FactoryFeeConfig} from "src/types/Factory.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct, TestERC1155Token} from "./TestHelpers.t.sol";
import {AccessControlled} from "src/abstracts/AccessControlled.sol";

import {GateLib} from "src/libraries/GateLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";
import {RewardLib} from "src/libraries/RewardLib.sol";
import {CurrencyLib, Currency} from "src/libraries/CurrencyLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {SubscriptionLib} from "src/libraries/SubscriptionLib.sol";
import {RewardPool} from "src/RewardPool.sol";
