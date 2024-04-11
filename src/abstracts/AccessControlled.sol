// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

abstract contract AccessControlled {
    /// @dev Triggered when the owner is changed
    event OwnerChanged(address indexed owner);

    /// @dev Triggered when roles are changed
    event RoleChanged(address indexed account, uint16 role);

    /// @dev Triggered when a new owner is proposed
    event OwnerProposed(address indexed proposed);

    /// @dev Not authorized error
    error NotAuthorized();

    /// @dev Invalid role mask error
    error InvalidRoleMask(uint8 role);

    address private _owner;
    address private _pendingOwner;

    mapping(address => uint16) private _roles;

    /// @dev Check if the caller is the owner
    function _checkOwner() internal view {
        if (msg.sender != _owner) revert NotAuthorized();
    }

    /// @dev Check if the caller has the required role (owner can do anything)
    function _checkRoles(uint16 roles) internal view {
        if (_roles[msg.sender] & roles == 0) revert NotAuthorized();
    }

    function _checkOwnerOrRoles(uint16 roles) internal view {
        if (msg.sender != _owner && _roles[msg.sender] & roles == 0) revert NotAuthorized();
    }

    /// @dev Set the owner (initialization)
    function _setOwner(address account) internal {
        _owner = account;
        _pendingOwner = address(0);
        emit OwnerChanged(account);
    }

    ///////////////////////////////////////////////////

    /**
     * @notice Set the pending owner of the contract
     * @param account the account to set as pending owner
     */
    function setPendingOwner(address account) external {
        _checkOwner();
        _pendingOwner = account;
        emit OwnerProposed(account);
    }

    /**
     * @notice Accept the ownership of the contract as proposed owner
     */
    function acceptOwnership() external {
        if (msg.sender != _pendingOwner) revert NotAuthorized();
        _setOwner(_pendingOwner);
    }

    /**
     * @notice Set the roles for an account
     * @param account the account to grant the role to
     * @param roles the role to grant (bitmask)
     */
    function setRoles(address account, uint16 roles) external {
        _checkOwner();
        _roles[account] = roles;
        emit RoleChanged(account, roles);
    }

    /**
     * @notice Get the owner of the contract
     * @return account owner of the contract
     */
    function owner() external view returns (address account) {
        return _owner;
    }
}
