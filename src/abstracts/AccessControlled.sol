// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

abstract contract AccessControlled {
    /// @dev Triggered when the owner is changed
    event OwnerChanged(address indexed owner);

    /// @dev Triggered when roles are changed
    event RoleChanged(address indexed account, uint8 role);

    /// @dev Triggered when a new owner is proposed
    event OwnerProposed(address indexed proposed);

    /// @dev Not authorized error
    error NotAuthorized();

    /// @dev Invalid role mask error
    error InvalidRoleMask(uint8 role);

    uint8 internal constant ROLE_MANAGER = 0x1;
    uint8 internal constant ROLE_AGENT = 0x2;

    address private _owner;
    address private _pendingOwner;

    mapping(address => uint8) private _roles;

    /// @dev Check if the caller is the owner
    function checkOwner() internal view {
        if (msg.sender != _owner) {
            revert NotAuthorized();
        }
    }

    /// @dev Check if the caller has the required role (owner can do anything)
    function checkRole(uint8 role) internal view {
        if (msg.sender != _owner && (_roles[msg.sender] & role) == 0) {
            revert NotAuthorized();
        }
    }

    /// @dev Set the owner (initialization)
    function setOwner(address account) internal {
        _owner = account;
        _pendingOwner = address(0);
        emit OwnerChanged(account);
    }

    /**
     * @notice Set the pending owner of the contract
     * @param account the account to set as pending owner
     */
    function setPendingOwner(address account) external {
        checkOwner();
        _pendingOwner = account;
        emit OwnerProposed(account);
    }

    /**
     * @notice Accept the ownership of the contract as proposed owner
     */
    function acceptOwnership() external {
        if (msg.sender != _pendingOwner) {
            revert NotAuthorized();
        }
        setOwner(_pendingOwner);
    }

    /**
     * @notice Set the roles for an account
     * @param account the account to grant the role to
     * @param roles the role to grant (bitmask)
     */
    function setRoles(address account, uint8 roles) external {
        checkOwner();
        if (roles > (ROLE_MANAGER | ROLE_AGENT)) {
            revert InvalidRoleMask(roles);
        }
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
