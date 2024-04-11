// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {RewardPool} from "./RewardPool.sol";
import {SubscriptionTokenV2} from "./SubscriptionTokenV2.sol";

import {FeeParams, InitParams, Tier} from "./types/Index.sol";
import {CurveParams, RewardParams, RewardPoolParams} from "./types/Rewards.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {LibClone} from "@solady/utils/LibClone.sol";

import {DeployParams, FactoryFeeConfig, RewardDeployParams} from "src/types/Factory.sol";

/**
 *
 * @title Fabric Subscription Token Factory Contract
 * @author Fabric Inc.
 *
 * @dev A factory which leverages Clones to deploy Fabric Subscription Token Contracts
 *
 */
contract STPV2Factory is Ownable2Step {
    /// @dev The maximum fee that can be charged for a subscription contract
    uint16 private constant _MAX_FEE_BIPS = 1250;

    /////////////////
    // Errors
    /////////////////

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
    event SubscriptionDeployment(address indexed deployment, uint256 feeId);

    /// @dev Emitted upon a successful reward pool deployment
    event RewardPoolDeployment(address indexed deployment);

    /// @dev Emitted when a new fee is created
    event FeeCreated(uint256 indexed id, address collector, uint16 bips, uint80 deployFee);

    /// @dev Emitted when a fee is destroyed
    event FeeDestroyed(uint256 indexed id);

    /// @dev Emitted when the deploy fees are collected by the owner
    event DeployFeeTransfer(address indexed recipient, uint256 amount);

    /////////////////

    /// @dev The STP contract implementation address
    address immutable _stpImplementation;

    /// @dev The default RewardPool contract implementation address
    address immutable _rewardPoolImplementation;

    /// @dev Configured fee ids and their config
    mapping(uint256 => FactoryFeeConfig) private _feeConfigs;

    uint256 private _salt;

    /**
     * @notice Construct a new Factory contract
     * @param stpImplementation the SubscriptionTokenV2 implementation address
     * @param rewardPoolImplementation the RewardPool implementation address
     */
    constructor(address stpImplementation, address rewardPoolImplementation) Ownable(msg.sender) {
        _stpImplementation = stpImplementation;
        _rewardPoolImplementation = rewardPoolImplementation;
        _salt = block.chainid << 128;
    }

    /**
     * @notice Deploy a new Clone of a RewardPool contract
     *
     * @param poolParams the initialization parameters for the pool
     * @param curveParams the curve parameters for the pool
     */
    function deployRewardPool(
        RewardPoolParams memory poolParams,
        CurveParams memory curveParams
    ) public returns (address deployment) {
        deployment = LibClone.clone(_rewardPoolImplementation);
        RewardPool(payable(deployment)).initialize(poolParams, curveParams);
        emit RewardPoolDeployment(deployment);
    }

    function deploySubscriptionWithPool(
        DeployParams memory params,
        RewardPoolParams memory poolParams,
        CurveParams memory curveParams
    ) public payable returns (address subscriptionAddress, address poolAddress) {
        poolAddress = deployRewardPool(poolParams, curveParams);

        // get the address of the subscription
        address predictedAddress =
            LibClone.predictDeterministicAddress(_stpImplementation, bytes32(_salt + 1), address(this));
        RewardPool(payable(poolAddress)).setRoles(predictedAddress, 1); // TODO Const RewardPool.ROLE_MINTER

        // set the reward pool address
        params.rewardParams.poolAddress = poolAddress;
        subscriptionAddress = deploySubscription(params);
    }

    /**
     * @notice Deploy a new Clone of a SubscriptionTokenV2 contract
     *
     * @param params the initialization parameters for the contract (@see DeloyParams)
     */
    function deploySubscription(DeployParams memory params) public payable returns (address) {
        // If an invalid fee id is provided, use the default fee (0)
        FactoryFeeConfig memory fees = _feeConfig(params.feeConfigId);

        // Transfer the deploy fee to the collector
        _transferDeployFee(fees);

        // Clone the implementation
        address deployment = LibClone.cloneDeterministic(_stpImplementation, bytes32(++_salt));

        // Set the owner to the sender if it is not set
        if (params.initParams.owner == address(0)) params.initParams.owner = msg.sender;

        // TODO
        // FeeParams memory rewardFees = FeeParams({collector: source, bips: bips, controller: address(this)});
        FeeParams memory subFees = FeeParams({collector: fees.collector, bips: fees.basisPoints});
        // Allow for the factory to control where fees go

        // TODO: Clone and build a thing
        // RewardParams memory rewardParams = RewardParams({
        //     rewardPool: params.rewardPool
        //     rewardBips: params.rewardBips
        // });

        SubscriptionTokenV2(payable(deployment)).initialize(
            params.initParams, params.tierParams, params.rewardParams, subFees
        );
        emit SubscriptionDeployment(deployment, params.feeConfigId);

        return deployment;
    }

    /**
     * @notice Create a fee for future deployments using that fee id
     * @param id the id of the fee for future deployments
     * @param config the fee configuration
     */
    function createFee(uint256 id, FactoryFeeConfig memory config) external onlyOwner {
        if (config.basisPoints == 0 || config.basisPoints > _MAX_FEE_BIPS) revert FeeBipsInvalid();
        if (config.collector == address(0)) revert FeeCollectorInvalid();
        if (_feeConfigs[id].collector != address(0)) revert FeeExists(id);
        _feeConfigs[id] = config;
        emit FeeCreated(id, config.collector, config.basisPoints, config.deployFee);
    }

    /**
     * @notice Destroy a fee schedule
     * @param id the id of the fee to destroy
     */
    function destroyFee(uint256 id) external onlyOwner {
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

    function _feeConfig(uint256 feeConfigId) internal view returns (FactoryFeeConfig memory fees) {
        FactoryFeeConfig memory _fees = _feeConfigs[feeConfigId];
        if (feeConfigId != 0 && _fees.collector == address(0)) _fees = _feeConfigs[0];
        return _fees;
    }

    /**
     * @dev Transfer the deploy fee to the collector (if configured)
     * @param fees the fee configuration
     */
    function _transferDeployFee(FactoryFeeConfig memory fees) internal {
        if (fees.deployFee == 0) return;

        if (msg.value < fees.deployFee) revert FeeInsufficient(fees.deployFee);

        emit DeployFeeTransfer(fees.collector, msg.value);
        (bool sent,) = payable(fees.collector).call{value: msg.value}("");
        if (!sent) revert FeeTransferFailed();
    }
}
