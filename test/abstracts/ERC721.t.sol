// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge/Test.sol";

import {ERC721} from "src/abstracts/ERC721.sol";

contract TestSubject is ERC721, Test {
    constructor(address account) {}

    function mint(address account, uint256 id) external {
        _mint(account, id);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
    }

    function name() public pure override returns (string memory) {
        return "TestSubject";
    }

    function symbol() public pure override returns (string memory) {
        return "TS";
    }

    function balanceOf(address) public pure override returns (uint256) {
        return 0; // Don't care
    }

    function locked(uint256) external pure returns (bool) {
        return false;
    }

    function test() public {}
}

contract Receiver is Test {
    error Nope();

    bool private _revert;
    bytes public _data;

    constructor(bool doRevert) {
        _revert = doRevert;
    }

    function onERC721Received(address, address, uint256, bytes calldata data) external returns (bytes4) {
        if (_revert) revert Nope();
        _data = data;
        return 0x150b7a02;
    }

    function test() public {}
}

contract ERC721Test is Test {
    address internal alice = 0xb4c79DAB8f259c7Aee6E5b2aa729821864227E81;
    address internal bob = 0xB4C79DAB8f259C7aEE6E5B2aa729821864227E8a;

    TestSubject public subject;

    function setUp() public {
        subject = new TestSubject(address(this));
    }

    function test165() public {
        assertTrue(subject.supportsInterface(0x01ffc9a7));
        assertTrue(subject.supportsInterface(0x80ac58cd));
        assertTrue(subject.supportsInterface(0x5b5e139f));
        assertTrue(subject.supportsInterface(0x49064906));
        assertFalse(subject.supportsInterface(0xdeadbeef));
    }

    function testMintApproveTransfer() public {
        subject.mint(alice, 1);
        subject.mint(alice, 2);
        subject.mint(alice, 3);
        assertEq(subject.ownerOf(1), alice);

        vm.expectRevert(ERC721.TokenAlreadyExists.selector);
        subject.mint(alice, 1);

        vm.startPrank(alice);
        subject.approve(bob, 1);
        assertEq(subject.getApproved(1), bob);
        subject.transferFrom(alice, bob, 2);

        vm.expectRevert(ERC721.TokenNotAuthorized.selector);
        subject.approve(bob, 4);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(ERC721.TokenNotAuthorized.selector);
        subject.transferFrom(alice, bob, 200);

        vm.expectRevert(ERC721.TransferToZeroAddress.selector);
        subject.transferFrom(alice, address(0), 1);

        vm.expectRevert(ERC721.TokenNotAuthorized.selector);
        subject.transferFrom(alice, bob, 3);

        subject.transferFrom(alice, bob, 1);
        subject.setApprovalForAll(alice, true);
        assertTrue(subject.isApprovedForAll(bob, alice));
        vm.stopPrank();

        vm.startPrank(alice);
        subject.transferFrom(bob, alice, 1);
        vm.stopPrank();
    }

    function testSafeTransfer() public {
        subject.mint(alice, 1);
        subject.mint(alice, 2);
        vm.startPrank(alice);
        subject.safeTransferFrom(alice, bob, 1);
        subject.safeTransferFrom(alice, bob, 2, "true");
        vm.stopPrank();

        Receiver receiver1 = new Receiver(true);
        Receiver receiver2 = new Receiver(false);

        vm.startPrank(bob);
        vm.expectRevert(0xd1a57ed6);
        subject.safeTransferFrom(bob, address(this), 1);

        vm.expectRevert(Receiver.Nope.selector);
        subject.safeTransferFrom(bob, address(receiver1), 1);
        subject.safeTransferFrom(bob, address(receiver2), 1, "meow");
        assertEq(receiver2._data(), "meow");
        vm.stopPrank();
    }
}
