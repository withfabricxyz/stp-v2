// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.25;

import {AccessControlled} from "./abstracts/AccessControlled.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {STPV2} from "./STPV2.sol";
import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";
import "./types/Constants.sol";
import {FeeParams, InitParams, Tier} from "./types/Index.sol";
import {CurveParams, RewardParams} from "./types/Rewards.sol";
import {DeployParams, FeeScheduleView} from "src/types/Factory.sol";

/**
 *
 * @title Fabric Subscription Token Factory Contract
 * @author Fabric Inc.
 * @dev A factory which leverages Clones to deploy Fabric Subscription Token Contracts
 */
contract STPV2Factory is AccessControlled, Multicallable {
    using CurrencyLib for Currency;

    /////////////////
    // Errors
    /////////////////

    /// @dev Error when the implementation address is invalid
    error InvalidImplementation();

    /// @dev Error when a fee collector is invalid (0 address)
    error InvalidFeeRecipient();

    /// @dev Error when the fee paid for deployment is insufficient
    error FeeInvalid();

    /////////////////
    // Events
    /////////////////

    /// @dev Emitted upon a successful subscription contract deployment
    event Deployment(address indexed deployment, bytes deployKey);

    /// @dev Emitted when the deploy fees are collected by the owner
    event DeployFeeTransfer(address indexed recipient, uint256 amount);

    /// @dev Emitted when a deploy fee is set
    event DeployFeeChange(uint256 amount);

    /// @dev Emitted when the protocol fee recipient is set
    event ProtocolFeeRecipientChange(address account);

    /////////////////

    /// @dev The STP contract implementation address
    address private immutable IMPLEMENTATION;

    /// @dev The protocol fee recipient
    address private _protocolFeeRecipient;

    /// @dev The deploy fee (how much to charge for deployment)
    uint256 private _deployFee;

    /**
     * @notice Construct a new Factory contract
     * @param stpImplementation the STPV2 implementation address
     */
    constructor(address stpImplementation, address protocolFeeRecipient) {
        if (stpImplementation == address(0)) revert InvalidImplementation();
        if (protocolFeeRecipient == address(0)) revert InvalidFeeRecipient();
        IMPLEMENTATION = stpImplementation;
        _protocolFeeRecipient = protocolFeeRecipient;
        _deployFee = 0;
        _setOwner(msg.sender);
    }

    /**
     * @notice Deploy a new Clone of a STPV2 contract
     *
     * @param params the initialization parameters for the contract (@see DeloyParams)
     */
    function deploySubscription(DeployParams memory params) public payable returns (address) {
        // Transfer the deploy fee if required
        _transferDeployFee();

        // Clone the implementation
        address deployment = LibClone.clone(IMPLEMENTATION);

        // Set the owner to the sender if it is not set
        if (params.initParams.owner == address(0)) params.initParams.owner = msg.sender;

        FeeParams memory subFees = FeeParams({
            protocolRecipient: _protocolFeeRecipient,
            protocolBps: PROTOCOL_FEE_BPS,
            clientRecipient: params.clientFeeRecipient,
            clientBps: params.clientFeeBps,
            clientReferralBps: params.clientReferralShareBps
        });

        emit Deployment(deployment, params.deployKey);
        STPV2(payable(deployment)).initialize(
            params.initParams, params.tierParams, params.rewardParams, params.curveParams, subFees
        );

        return deployment;
    }

    /**
     * @dev Transfer the deploy fee to the collector (if configured)
     */
    function _transferDeployFee() internal {
        if (msg.value != _deployFee) revert FeeInvalid();
        if (_deployFee == 0) return;
        if (_protocolFeeRecipient == address(0)) return;

        emit DeployFeeTransfer(_protocolFeeRecipient, msg.value);
        DEPLOY_FEE_CURRENCY.transfer(_protocolFeeRecipient, msg.value);
    }

    /**
     * @notice Set the protocol recipient for deployed contracts
     * @param recipient the new recipient
     */
    function setProtocolFeeRecipient(address recipient) external {
        _checkOwner();
        if (recipient == address(0)) revert InvalidFeeRecipient();
        _protocolFeeRecipient = recipient;
        emit ProtocolFeeRecipientChange(recipient);
    }

    /**
     * @notice Set the deploy fee (wei)
     * @param deployFeeWei the new deploy fee
     */
    function setDeployFee(uint256 deployFeeWei) external {
        _checkOwner();
        _deployFee = deployFeeWei;
        emit DeployFeeChange(deployFeeWei);
    }

    /**
     * @notice Get the current fee schedule
     * @return schedule the fee schedule
     */
    function feeSchedule() external view returns (FeeScheduleView memory schedule) {
        return
            FeeScheduleView({deployFee: _deployFee, protocolFeeBps: PROTOCOL_FEE_BPS, recipient: _protocolFeeRecipient});
    }

    /**
     * @notice Update the client fee recipient for a list of deployments
     * @dev requires the sender to be the current recipient
     * @param deployment the deployment to update
     * @param recipient the new recipient
     */
    function updateClientFeeRecipient(address payable deployment, address recipient) external {
        if (STPV2(deployment).feeDetail().clientRecipient != msg.sender) revert NotAuthorized();
        STPV2(deployment).updateClientFeeRecipient(recipient);
    }

    /**
     * @notice Update the protocol fee recipient for a list of deployments
     * @dev requires the sender to be the current recipient
     * @param deployment the deployment to update
     * @param recipient the new recipient
     */
    function updateProtocolFeeRecipient(address payable deployment, address recipient) external {
        if (STPV2(deployment).feeDetail().protocolRecipient != msg.sender) revert NotAuthorized();
        STPV2(deployment).updateProtocolFeeRecipient(recipient);
    }
}
