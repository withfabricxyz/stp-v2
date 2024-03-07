// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISubscriptionTokenV2} from "src/interfaces/ISubscriptionTokenV2.sol";
import {SubscriptionTokenV2} from "src/SubscriptionTokenV2.sol";
import {InitParams} from "src/types/InitParams.sol";
import {BaseTest, TestERC20Token, TestFeeToken, SelfDestruct} from "./TestHelpers.t.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AllocationLib} from "src/libraries/AllocationLib.sol";

contract SubscriptionTokenV2InitTest is BaseTest {
    InitParams private params;

    function setUp() public {
        vm.store(
            address(stp),
            bytes32(uint256(0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)),
            bytes32(0)
        );
    }

    function testOwnerZero() public {
        initParams.owner = address(0);

        vm.expectRevert("Owner address cannot be 0x0");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    // function testTps() public {
    //     initParams.tokensPerSecond = 0;

    //     vm.expectRevert("Tokens per second must be > 0");
    //     stp.initialize(initParams, tierParams, rewardParams, feeParams);
    // }

    function testFeeBps() public {
        feeParams.bips = 1500;

        vm.expectRevert("Fee bps too high");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testFeeRequirement() public {
        feeParams.collector = fees;

        vm.expectRevert("Fees required when fee recipient is present");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testMinPurchase() public {
        tierParams.periodDurationSeconds = 0;

        vm.expectRevert("Period duration must be > 0");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testRewardBpsTooHigh() public {
        rewardParams.rewardBps = 11000;

        vm.expectRevert("Reward bps too high");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testRewardHalvingsTooHigh() public {
        rewardParams.numRewardHalvings = 33;

        vm.expectRevert("Reward halvings too high");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testRewardHalvingsTooLow() public {
        rewardParams.numRewardHalvings = 0;
        rewardParams.rewardBps = 500;

        vm.expectRevert("Reward halvings too low");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptyName() public {
        initParams.name = "";

        vm.expectRevert("Name cannot be empty");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptySymbol() public {
        initParams.symbol = "";

        vm.expectRevert("Symbol cannot be empty");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptyContractURI() public {
        initParams.contractUri = "";

        vm.expectRevert("Contract URI cannot be empty");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }

    function testEmptyTokenURI() public {
        initParams.tokenUri = "";

        vm.expectRevert("Token URI cannot be empty");
        stp.initialize(initParams, tierParams, rewardParams, feeParams);
    }
}
