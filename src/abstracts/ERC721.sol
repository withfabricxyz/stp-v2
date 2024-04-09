// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../interfaces/IERC4906.sol";
import "../interfaces/IERC5192.sol";

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol), Modified by Fabric
abstract contract ERC721 is IERC4906, IERC5192 {
    /// @dev Only the token owner or an approved account can manage the token.
    error TokenNotAuthorized();

    /// @dev The token does not exist.
    error TokenDoesNotExist();

    /// @dev The token already exists.
    error TokenAlreadyExists();

    // /// @dev Cannot mint or transfer to the zero address.
    error TransferToZeroAddress();

    // /// @dev Cannot safely transfer to a contract that does not implement
    // /// the ERC721Receiver interface.
    error TransferToNonERC721ReceiverImplementer();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 id) public view virtual returns (string memory);

    function name() public view virtual returns (string memory);

    function symbol() public view virtual returns (string memory);

    function balanceOf(address owner) public view virtual returns (uint256);

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        if ((owner = _ownerOf[id]) == address(0)) revert TokenDoesNotExist();
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];
        if (!(msg.sender == owner || isApprovedForAll[owner][msg.sender])) revert TokenNotAuthorized();

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) public virtual {
        if (from != _ownerOf[id]) revert TokenNotAuthorized();
        if (to == address(0)) revert TransferToZeroAddress();
        if (!(msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id])) {
            revert TokenNotAuthorized();
        }

        _beforeTokenTransfer(from, to, id);

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public virtual {
        transferFrom(from, to, id);
        _checkReceiver(from, to, id, "");
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public virtual {
        transferFrom(from, to, id);
        _checkReceiver(from, to, id, data);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f // ERC165 Interface ID for ERC721Metadata
            || interfaceId == 0x49064906 // ERC165 Interface ID for ERC4906
            || interfaceId == 0xb45a3c0e; // ERC165 Interface ID for ERC5192
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        if (to == address(0)) revert TransferToZeroAddress();
        if (_ownerOf[id] != address(0)) revert TokenAlreadyExists();

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);
        _checkReceiver(address(0), to, id, "");
    }

    function _checkReceiver(address from, address to, uint256 id, bytes memory data) private {
        if (
            !(
                to.code.length == 0
                    || ERC721TokenReceiver(to).onERC721Received(to, from, id, data)
                        == ERC721TokenReceiver.onERC721Received.selector
            )
        ) revert TransferToNonERC721ReceiverImplementer();
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
