// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {LibClone} from "@solady/utils/LibClone.sol";

import {STPV2} from "./STPV2.sol";

import {AccessControlled} from "./abstracts/AccessControlled.sol";

import {Currency, CurrencyLib} from "./libraries/CurrencyLib.sol";
import "./types/Constants.sol";
import {FeeParams, InitParams, Tier} from "./types/Index.sol";
import {CurveParams, RewardParams} from "./types/Rewards.sol";
import {DeployParams, FactoryFeeConfig} from "src/types/Factory.sol";

/**
 *
 * @title Fabric Subscription Token Factory Contract
 * @author Fabric Inc.
 * @dev A factory which leverages Clones to deploy Fabric Subscription Token Contracts
 */
contract STPV2Factory is AccessControlled {
    using CurrencyLib for Currency;

    /////////////////
    // Errors
    /////////////////

    /// @dev Error when the implementation address is invalid
    error InvalidImplementation();

    /// @dev Error when a fee id is not found (for removal)
    error FeeNotFound(uint256 id);

    /// @dev Error when a fee id already exists
    error FeeExists(uint256 id);

    /// @dev Error when a fee collector is invalid (0 address)
    error FeeCollectorInvalid();

    /// @dev Error when a fee bips is invalid (0 or too high)
    error FeeBipsInvalid();

    /// @dev Error when the fee paid for deployment is insufficient
    error FeeInsufficient(uint256 amountRequired);

    /// @dev Error when the fee balance is zero (fee transfer)
    error FeeBalanceZero();

    /// @dev Error when the fee transfer fails
    error FeeTransferFailed();

    /////////////////
    // Events
    /////////////////

    /// @dev Emitted upon a successful subscription contract deployment
    event Deployment(address indexed deployment, uint256 feeId, bytes deployKey);

    /// @dev Emitted when a new fee is created
    event FeeCreated(uint256 indexed id, address collector, uint16 bips, uint80 deployFee);

    /// @dev Emitted when a fee is destroyed
    event FeeDestroyed(uint256 indexed id);

    /// @dev Emitted when the deploy fees are collected by the owner
    event DeployFeeTransfer(address indexed recipient, uint256 amount);

    /////////////////

    /// @dev The deploy fee currency (ETH)
    Currency private immutable _deployFeeCurrency = Currency.wrap(address(0));

    /// @dev The STP contract implementation address
    address immutable _stpImplementation;

    /// @dev Configured fee ids and their config
    mapping(uint256 => FactoryFeeConfig) private _feeConfigs;

    /**
     * @notice Construct a new Factory contract
     * @param stpImplementation the STPV2 implementation address
     */
    constructor(address stpImplementation) {
        if (stpImplementation == address(0)) revert InvalidImplementation();
        _stpImplementation = stpImplementation;
        _setOwner(msg.sender);
    }

    /**
     * @notice Deploy a new Clone of a STPV2 contract
     *
     * @param params the initialization parameters for the contract (@see DeloyParams)
     */
    function deploySubscription(DeployParams memory params) public payable returns (address) {
        // If an invalid fee id is provided, use the default fee (0)
        uint256 feeConfigId = _resolveFeeId(params.feeConfigId);
        FactoryFeeConfig memory fees = _feeConfigs[feeConfigId];

        // Transfer the deploy fee to the collector
        _transferDeployFee(fees);

        // Clone the implementation
        address deployment = LibClone.clone(_stpImplementation);

        // Set the owner to the sender if it is not set
        if (params.initParams.owner == address(0)) params.initParams.owner = msg.sender;

        FeeParams memory subFees = FeeParams({collector: fees.collector, bips: fees.basisPoints});

        emit Deployment(deployment, feeConfigId, params.deployKey);
        STPV2(payable(deployment)).initialize(
            params.initParams, params.tierParams, params.rewardParams, params.curveParams, subFees
        );

        return deployment;
    }

    /**
     * @notice Create a fee for future deployments using that fee id
     * @param id the id of the fee for future deployments
     * @param config the fee configuration
     */
    function createFee(uint256 id, FactoryFeeConfig memory config) external {
        _checkOwner();
        if (config.basisPoints == 0 || config.basisPoints > MAX_FEE_BPS) revert FeeBipsInvalid();
        if (config.collector == address(0)) revert FeeCollectorInvalid();
        if (_feeConfigs[id].collector != address(0)) revert FeeExists(id);
        _feeConfigs[id] = config;
        emit FeeCreated(id, config.collector, config.basisPoints, config.deployFee);
    }

    /**
     * @notice Destroy a fee schedule
     * @param id the id of the fee to destroy
     */
    function destroyFee(uint256 id) external {
        _checkOwner();
        if (_feeConfigs[id].collector == address(0)) revert FeeNotFound(id);
        emit FeeDestroyed(id);
        delete _feeConfigs[id];
    }

    /**
     * @notice Fetch the fee schedule for a given fee id
     * @param feeId the id of the fee to fetch
     * @return fees the configuration for the fee id
     */
    function feeInfo(uint256 feeId) external view returns (FactoryFeeConfig memory fees) {
        return _feeConfigs[feeId];
    }

    /////////////////
    function _resolveFeeId(uint256 feeConfigId) internal view returns (uint256 id) {
        if (_feeConfigs[feeConfigId].collector == address(0)) return 0;
        return feeConfigId;
    }

    /**
     * @dev Transfer the deploy fee to the collector (if configured)
     * @param fees the fee configuration
     */
    function _transferDeployFee(FactoryFeeConfig memory fees) internal {
        if (fees.deployFee == 0) return;
        if (fees.collector == address(0)) return;
        if (msg.value < fees.deployFee) revert FeeInsufficient(fees.deployFee);
        emit DeployFeeTransfer(fees.collector, msg.value);
        _deployFeeCurrency.transfer(fees.collector, msg.value);
    }
}
