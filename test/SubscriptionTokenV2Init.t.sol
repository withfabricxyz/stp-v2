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
        params = initParams();
        stp = createStp(params);
        vm.store(
            address(stp),
            bytes32(uint256(0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)),
            bytes32(0)
        );
    }

    function testOwnerZero() public {
        params.owner = address(0);

        vm.expectRevert("Owner address cannot be 0x0");
        stp.initialize(params);
    }

    function testTps() public {
        params.tokensPerSecond = 0;

        vm.expectRevert("Tokens per second must be > 0");
        stp.initialize(params);
    }

    function testFeeBps() public {
        params.feeBps = 1500;

        vm.expectRevert("Fee bps too high");
        stp.initialize(params);
    }

    function testFeeRequirement() public {
        params.feeRecipient = fees;

        vm.expectRevert("Fees required when fee recipient is present");
        stp.initialize(params);
    }

    function testMinPurchase() public {
        params.minimumPurchaseSeconds = 0;

        vm.expectRevert("Min purchase seconds must be > 0");
        stp.initialize(params);
    }

    function testRewardBpsTooHigh() public {
        params.rewardBps = 11000;

        vm.expectRevert("Reward bps too high");
        stp.initialize(params);
    }

    function testRewardHalvingsTooHigh() public {
        params.numRewardHalvings = 33;

        vm.expectRevert("Reward halvings too high");
        stp.initialize(params);
    }

    function testRewardHalvingsTooLow() public {
        params.numRewardHalvings = 0;
        params.rewardBps = 500;

        vm.expectRevert("Reward halvings too low");
        stp.initialize(params);
    }

    function testEmptyName() public {
        params.name = "";

        vm.expectRevert("Name cannot be empty");
        stp.initialize(params);
    }

    function testEmptySymbol() public {
        params.symbol = "";

        vm.expectRevert("Symbol cannot be empty");
        stp.initialize(params);
    }

    function testEmptyContractURI() public {
        params.contractUri = "";

        vm.expectRevert("Contract URI cannot be empty");
        stp.initialize(params);
    }

    function testEmptyTokenURI() public {
        params.tokenUri = "";

        vm.expectRevert("Token URI cannot be empty");
        stp.initialize(params);
    }
}
