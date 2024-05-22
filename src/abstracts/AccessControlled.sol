// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/// @title AccessControlled
/// @dev Opinionated contract module that provides access control mechanisms using role bitmaps
///      When extending this, ensure your roles are unique powers of 2 and do not overlap, eg: 1, 2, 4, 8, 16, 32, etc
///      The owner can do anything, and roles can be granted to other accounts
///      The owner can propose a new owner, and the new owner must accept the proposal
///      The owner can grant roles to other accounts.
///      The owner can also revoke roles from other accounts (by setting the role to 0, or updating to bitmap)
abstract contract AccessControlled {
    /// @dev Triggered when the owner is changed
    event OwnerChanged(address indexed owner);

    /// @dev Triggered when roles are changed
    event RoleChanged(address indexed account, uint16 role);

    /// @dev Triggered when a new owner is proposed
    event OwnerProposed(address indexed proposed);

    /// @dev Not authorized error
    error NotAuthorized();

    /// @dev The current owner, which should be initialized in the constructor or initializer
    address private _owner;

    /// @dev The pending owner, which is set when the owner proposes a new owner
    address private _pendingOwner;

    /// @dev The roles for each account
    mapping(address => uint16) private _roles;

    /// @dev Check if the caller is the owner
    function _checkOwner() internal view {
        if (msg.sender != _owner) revert NotAuthorized();
    }

    /// @dev Check if the caller has the required role (owner can do anything)
    function _checkRoles(uint16 roles) internal view {
        if (_roles[msg.sender] & roles == 0) revert NotAuthorized();
    }

    /// @dev Check if the caller is the owner or has the required role (owner can do anything)
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
     * @param account the account to grant the role(s) to
     * @param roles the role(s) to grant
     */
    function setRoles(address account, uint16 roles) external {
        _checkOwner();
        _roles[account] = roles;
        emit RoleChanged(account, roles);
    }

    /**
     * @notice Get the role bitmap for an account
     * @param account the account to check
     * @return roles the role(s) granted, or 0 if none
     */
    function rolesOf(address account) external view returns (uint16 roles) {
        return _roles[account];
    }

    /**
     * @notice Get the owner of the contract
     * @return account owner of the contract
     */
    function owner() external view returns (address account) {
        return _owner;
    }

    /**
     * @notice Get the pending owner of the contract
     * @return account pending owner of the contract
     */
    function pendingOwner() external view returns (address account) {
        return _pendingOwner;
    }
}
