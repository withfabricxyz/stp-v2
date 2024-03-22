// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/Index.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";
import {RewardLib} from "src/libraries/RewardLib.sol";
import {TierLib} from "src/libraries/TierLib.sol";

contract InitializationTest is BaseTest {
    InitParams private params;

    function setUp() public {
        stp = new SubscriptionTokenV2();
        vm.store(
            address(stp),
            bytes32(uint256(0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)),
            bytes32(0)
        );
    }

    function testDefaults() public {
        stp = reinitStp();
        assertEq(initParams.tokenUri, stp.baseTokenURI());
        assertEq(initParams.contractUri, stp.contractURI());
        assertEq(initParams.erc20TokenAddr, stp.erc20Address());
    }

    function testOwnerZero() public {
        initParams.owner = address(0);

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidOwner.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testFeeBps() public {
        feeParams.bips = 1500;

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidBps.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testFeeRequirement() public {
        feeParams.collector = fees;

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidBps.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testMinPurchase() public {
        tierParams.periodDurationSeconds = 0;

        vm.expectRevert(abi.encodeWithSelector(TierLib.TierInvalidDuration.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testInvalidRewards() public {
        rewardParams.bips = 11000;
        vm.expectRevert(abi.encodeWithSelector(RewardLib.RewardBipsTooHigh.selector, 11000));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptyName() public {
        initParams.name = "";

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidName.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptySymbol() public {
        initParams.symbol = "";

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidSymbol.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptyContractURI() public {
        initParams.contractUri = "";

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidContractUri.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptyTokenURI() public {
        initParams.tokenUri = "";

        vm.expectRevert(abi.encodeWithSelector(ISubscriptionTokenV2.InvalidTokenUri.selector));
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }
}
