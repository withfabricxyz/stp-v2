// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SubscriptionTokenV2} from "./SubscriptionTokenV2.sol";
import {InitParams, Tier, DeployParams, FeeParams, RewardParams, RewardPoolParams} from "./types/Index.sol";

/**
 *
 * @title Fabric Subscription Token Factory Contract
 * @author Fabric Inc.
 *
 * @dev A factory which leverages Clones to deploy Fabric Subscription Token Contracts
 *
 */
contract SubscriptionTokenV2Factory is Ownable2Step {
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

    /// @dev Emitted upon a successful contract deployment
    event Deployment(address indexed deployment, uint256 feeId);

    /// @dev Emitted when a new fee is created
    event FeeCreated(uint256 indexed id, address collector, uint16 bips);

    /// @dev Emitted when a fee is destroyed
    event FeeDestroyed(uint256 indexed id);

    /// @dev Emitted when the deployment fee changes
    event DeployFeeChange(uint256 amount);

    /// @dev Emitted when the deploy fees are collected by the owner
    event DeployFeeTransfer(address indexed recipient, uint256 amount);

    /////////////////

    /// @dev Guard to ensure the deploy fee is met
    modifier feeRequired() {
        if (msg.value < _feeDeployMin) {
            revert FeeInsufficient(_feeDeployMin);
        }
        _;
    }

    /// @dev The campaign contract implementation address
    address immutable _implementation;

    /// @dev Fee configuration for agreements and revshare
    struct FeeConfig {
        address collector;
        uint16 basisPoints;
    }

    /// @dev Configured fee ids and their config
    mapping(uint256 => FeeConfig) private _feeConfigs;

    /// @dev Fee to collect upon deployment
    uint256 private _feeDeployMin;

    /**
     * @param implementation the SubscriptionTokenV2 implementation address
     */
    constructor(address implementation) Ownable(msg.sender) {
        _implementation = implementation;
        _feeDeployMin = 0;
    }

    // deployRewardPool
    // deploySubscription
    // deploySubscriptionWithRewardPool

    /**
     * @notice Deploy a new Clone of a SubscriptionTokenV2 contract
     *
     * @param params the initialization parameters for the contract (@see DeloyParams)
     */
    function deploySubscription(DeployParams memory params) public payable feeRequired returns (address) {
        // If an invalid fee id is provided, use the default fee (0)
        FeeParams memory fees = _feeConfig(params.feeConfigId);
        address deployment = Clones.clone(_implementation);

        // Set the owner to the sender if it is not set
        if (params.initParams.owner == address(0)) {
            params.initParams.owner = msg.sender;
        }

        // TODO
        RewardParams memory rewardParams = RewardParams({poolAddress: address(0), bips: params.poolParams.bips});

        // TODO: Clone and build a thing
        // RewardParams memory rewardParams = RewardParams({
        //     rewardPool: params.rewardPool
        //     rewardBips: params.rewardBips
        // });

        SubscriptionTokenV2(payable(deployment)).initialize(params.initParams, params.tierParams, rewardParams, fees);
        emit Deployment(deployment, params.feeConfigId);

        return deployment;
    }

    /**
     * @dev Owner Only: Transfer accumulated fees
     * @param recipient the address to transfer the fees to
     */
    function transferDeployFees(address recipient) external onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) {
            revert FeeBalanceZero();
        }
        emit DeployFeeTransfer(recipient, amount);
        (bool sent,) = payable(recipient).call{value: amount}("");
        if (!sent) {
            revert FeeTransferFailed();
        }
    }

    /**
     * @notice Create a fee for future deployments using that fee id
     * @param id the id of the fee for future deployments
     * @param collector the address of the fee collector
     * @param bips the fee in basis points, allocated during withdraw
     */
    function createFee(uint256 id, address collector, uint16 bips) external onlyOwner {
        if (bips == 0 || bips > _MAX_FEE_BIPS) {
            revert FeeBipsInvalid();
        }
        if (collector == address(0)) {
            revert FeeCollectorInvalid();
        }
        if (_feeConfigs[id].collector != address(0)) {
            revert FeeExists(id);
        }
        _feeConfigs[id] = FeeConfig(collector, bips);
        emit FeeCreated(id, collector, bips);
    }

    /**
     * @notice Destroy a fee schedule
     * @param id the id of the fee to destroy
     */
    function destroyFee(uint256 id) external onlyOwner {
        if (_feeConfigs[id].collector == address(0)) {
            revert FeeNotFound(id);
        }
        emit FeeDestroyed(id);
        delete _feeConfigs[id];
    }

    /**
     * @notice Update the deploy fee (wei)
     * @param minFeeAmount the amount of wei required to deploy a campaign
     */
    function updateMinimumDeployFee(uint256 minFeeAmount) external onlyOwner {
        _feeDeployMin = minFeeAmount;
        emit DeployFeeChange(minFeeAmount);
    }

    /**
     * @notice Fetch the fee schedule for a given fee id
     * @return collector the address of the fee collector, or the 0 address if no fees are collected
     * @return bips the fee in basis points, allocated during withdraw
     * @return deployFeeWei the amount of wei required to deploy a campaign
     */
    function feeInfo(uint256 feeId) external view returns (address collector, uint16 bips, uint256 deployFeeWei) {
        FeeConfig memory fees = _feeConfigs[feeId];
        return (fees.collector, fees.basisPoints, _feeDeployMin);
    }

    /////////////////

    function _feeConfig(uint256 feeConfigId) internal view returns (FeeParams memory fees) {
        FeeConfig memory _fees = _feeConfigs[feeConfigId];
        if (feeConfigId != 0 && _fees.collector == address(0)) {
            _fees = _feeConfigs[0];
        }
        return FeeParams({collector: _fees.collector, bips: _fees.basisPoints});
    }
}
