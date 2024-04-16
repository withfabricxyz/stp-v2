// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../TestImports.t.sol";

contract MockCurrencyLib {
    function capture(Currency currency, address from, uint256 amount) public payable returns (uint256 capturedAmount) {
        return CurrencyLib.capture(currency, from, amount);
    }

    function transfer(Currency currency, address to, uint256 amount) public {
        CurrencyLib.transfer(currency, to, amount);
    }

    /// @dev show the balance of the contract
    function balance(Currency currency) public view returns (uint256) {
        return CurrencyLib.balance(currency);
    }

    /// @dev is the currency the native token, eg: ETH
    function isNative(Currency currency) public pure returns (bool) {
        return CurrencyLib.isNative(currency);
    }

    function test() public {}
}

contract CurrencyLibTest is Test {
    address internal alice = 0xb4c79DAB8f259c7Aee6E5b2aa729821864227E81;

    MockCurrencyLib public shim = new MockCurrencyLib();

    TestERC20Token testToken;
    TestFeeToken feeTaking;

    Currency eth;
    Currency usdc;
    Currency spendy;

    function setUp() public {
        testToken = new TestERC20Token("usdc", "usdc", 6);
        feeTaking = new TestFeeToken("spendy", "spendy", 1e20);
        eth = Currency.wrap(address(0));
        usdc = Currency.wrap(address(testToken));
        spendy = Currency.wrap(address(feeTaking));

        deal(alice, 1e18);
        testToken.transfer(alice, 1e9);
        feeTaking.transfer(alice, 2e9);
    }

    function testEth() public {
        assert(shim.isNative(eth));
        assertEq(shim.balance(eth), 0);

        vm.startPrank(alice);
        shim.capture{value: 1e9}(eth, alice, 1e9);
        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidCapture.selector));
        shim.capture{value: 1e7}(eth, alice, 1e9);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidAccount.selector));
        shim.transfer(eth, address(0), 1e9);

        assertEq(shim.balance(eth), 1e9);
        shim.transfer(eth, alice, 1e9);
        assertEq(shim.balance(eth), 0);
    }

    function testUsdc() public {
        assert(!shim.isNative(usdc));
        assertEq(shim.balance(usdc), 0);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(CurrencyLib.InvalidCapture.selector));
        shim.capture{value: 1e9}(usdc, alice, 1e9);
        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.TransferFromFailed.selector));
        shim.capture(usdc, alice, 1e5);

        testToken.approve(address(shim), 1e18);
        shim.capture(usdc, alice, 1e5);
        vm.stopPrank();

        assertEq(shim.balance(usdc), 1e5);
        shim.transfer(usdc, alice, 1e5);
        assertEq(shim.balance(eth), 0);
    }

    function testFeeTaking() public {
        vm.startPrank(alice);
        feeTaking.approve(address(shim), 1e18);
        uint256 pulled = shim.capture(spendy, alice, 2e9);
        vm.stopPrank();

        assertEq(pulled, 1e9);
        assertEq(shim.balance(spendy), 1e9);
    }
}
