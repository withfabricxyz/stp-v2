// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 {
    error InvalidRecipient();
    error ApprovalNotAuthorized();
    error NotMinted();
    error AlreadyMinted();
    error UnsafeRecipient();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    function balanceOf(address owner) public view virtual returns (uint256);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        if ((owner = _ownerOf[id]) == address(0)) {
            revert NotMinted();
        }
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        if (!(msg.sender == owner || isApprovedForAll[owner][msg.sender])) {
            revert ApprovalNotAuthorized();
        }

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) public virtual {
        if (from != _ownerOf[id]) {
            revert ApprovalNotAuthorized();
        }

        _checkAccount(to);

        if (!(msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id])) {
            revert ApprovalNotAuthorized();
        }

        _beforeTokenTransfer(from, to, id);

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public virtual {
        transferFrom(from, to, id);

        if (
            !(
                to.code.length == 0
                    || ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "")
                        == ERC721TokenReceiver.onERC721Received.selector
            )
        ) {
            revert UnsafeRecipient();
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        _checkAccount(to);

        if (_ownerOf[id] != address(0)) {
            revert AlreadyMinted();
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        if (
            !(
                to.code.length == 0
                    || ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "")
                        == ERC721TokenReceiver.onERC721Received.selector
            )
        ) {
            revert UnsafeRecipient();
        }
    }

    function _checkAccount(address account) private pure {
        if (account == address(0)) {
            revert InvalidRecipient();
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
