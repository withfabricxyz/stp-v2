// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SubscriptionTokenV2} from "./SubscriptionTokenV2.sol";
import {InitParams, TierInitParams, DeployParams, FeeParams} from "./types/InitParams.sol";

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

    /// @dev The number of reward halvings
    uint8 private constant _DEFAULT_REWARD_HALVINGS = 6;

    /// @dev Guard to ensure the deploy fee is met
    modifier feeRequired() {
        require(msg.value >= _feeDeployMin, "Insufficient ETH to deploy");
        _;
    }

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

    // /**
    //  * @notice Deploy a new Clone of a SubscriptionTokenV2 contract
    //  *
    //  * @param name the name of the collection
    //  * @param symbol the symbol of the collection
    //  * @param contractURI the metadata URI for the collection
    //  * @param tokenURI the metadata URI for the tokens
    //  * @param tokensPerSecond the number of base tokens required for a single second of time
    //  * @param minimumPurchaseSeconds the minimum number of seconds an account can purchase
    //  * @param rewardBps the basis points for reward allocations
    //  * @param erc20TokenAddr the address of the ERC20 token used for purchases, or the 0x0 for native
    //  * @param feeConfigId the fee configuration id to use for this deployment (if the id is invalid, the default fee is used)
    //  */
    function deploySubscription(DeployParams memory params) public payable feeRequired returns (address) {
        // If an invalid fee id is provided, use the default fee (0)
        FeeParams memory fees = _feeConfig(params.feeConfigId);

        address deployment = Clones.clone(_implementation);
        // SubscriptionTokenV2 token = SubscriptionTokenV2(payable(deployment));

        // Initialize rewards
        if (params.initParams.owner == address(0)) {
            params.initParams.owner = msg.sender;
        }

        // params.initParams.feeBps = fees.bips;
        // params.rewardParams.rewardBps = params.initParams.rewardBps;

        SubscriptionTokenV2(payable(deployment)).initialize(
            params.initParams, params.tierParams, params.rewardParams, fees
        );
        emit Deployment(deployment, params.feeConfigId); // TODO: Extra data for event to bind to dapp records

        return deployment;
    }

    function _feeConfig(uint256 feeConfigId) internal view returns (FeeParams memory fees) {
        FeeConfig memory _fees = _feeConfigs[feeConfigId];
        if (feeConfigId != 0 && _fees.collector == address(0)) {
            _fees = _feeConfigs[0];
        }
        return FeeParams({collector: _fees.collector, bips: _fees.basisPoints});
    }

    /**
     * @dev Owner Only: Transfer accumulated fees
     * @param recipient the address to transfer the fees to
     */
    function transferDeployFees(address recipient) external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "No fees to collect");
        emit DeployFeeTransfer(recipient, amount);
        (bool sent,) = payable(recipient).call{value: amount}("");
        require(sent, "Failed to transfer Ether");
    }

    /**
     * @notice Create a fee for future deployments using that fee id
     * @param id the id of the fee for future deployments
     * @param collector the address of the fee collector
     * @param bips the fee in basis points, allocated during withdraw
     */
    function createFee(uint256 id, address collector, uint16 bips) external onlyOwner {
        require(bips <= _MAX_FEE_BIPS, "Fee exceeds maximum");
        require(bips > 0, "Fee cannot be 0");
        require(collector != address(0), "Collector cannot be 0x0");
        require(_feeConfigs[id].collector == address(0), "Fee exists");
        _feeConfigs[id] = FeeConfig(collector, bips);
        emit FeeCreated(id, collector, bips);
    }

    /**
     * @notice Destroy a fee schedule
     * @param id the id of the fee to destroy
     */
    function destroyFee(uint256 id) external onlyOwner {
        require(_feeConfigs[id].collector != address(0), "Fee does not exists");
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
}
