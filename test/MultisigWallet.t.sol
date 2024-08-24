// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {
    MultisigWallet public wallet;
    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        MultisigWallet.TransactionType indexed _transactionType,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data,
        address tokenAddress,
        uint256 amountOrTokenId,
        address owner
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(
        MultisigWallet.TransactionType indexed _transactionType,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data,
        address tokenAddress,
        uint256 amountOrTokenId,
        address owner
    );
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    function setUp() public {
        owner1 = address(1);
        owner2 = address(2);
        owner3 = address(3);
        nonOwner = address(4);

        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        wallet = new MultisigWallet(owners);
    }

    function testInitialState() public {
        assertEq(wallet.getOwnerCount(), 2);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertFalse(wallet.isOwner(owner3));
        assertEq(wallet.numNormalDecisionConfirmations(), 2);
        assertEq(wallet.numImportantDecisionConfirmations(), 2);
    }

    function testDeposit() public {
        uint256 depositAmount = 1 ether;
        vm.expectEmit(true, false, false, true);
        emit Deposit(address(this), depositAmount, depositAmount);
        (bool success, ) = address(wallet).call{value: depositAmount}("");
        assertTrue(success);
        assertEq(address(wallet).balance, depositAmount);
    }

    function testSubmitTransaction() public {
        vm.prank(owner1);
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            owner2,
            1 ether,
            "",
            address(0),
            1 ether,
            owner1
        );
        wallet.sendETH(owner2, 1 ether);
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        wallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner1, 0);
        wallet.confirmTransaction(0);

        (, , , , bool isActive, uint256 numConfirmations, ) = wallet
            .transactions(0);
        assertTrue(isActive);
        assertEq(numConfirmations, 1);
    }

    function testExecuteTransaction() public {
        vm.deal(address(wallet), 2 ether);

        vm.prank(owner1);
        wallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            owner2,
            1 ether,
            "",
            address(0),
            1 ether,
            owner2
        );
        wallet.confirmTransaction(0);

        assertEq(address(wallet).balance, 1 ether);
        assertEq(owner2.balance, 1 ether);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit RevokeConfirmation(owner1, 0);
        wallet.revokeConfirmation(0);

        (, , , , bool isActive, uint256 numConfirmations, ) = wallet
            .transactions(0);
        assertTrue(isActive);
        assertEq(numConfirmations, 0);
    }

    function testAddOwner() public {
        vm.prank(owner1);
        wallet.addOwner(owner3);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectEmit(true, false, false, true);
        emit OwnerAdded(owner3);
        wallet.confirmTransaction(0);

        assertTrue(wallet.isOwner(owner3));
        assertEq(wallet.getOwnerCount(), 3);
    }

    function testRemoveOwner() public {
        vm.prank(owner1);
        wallet.removeOwner(owner2);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectEmit(true, false, false, true);
        emit OwnerRemoved(owner2);
        wallet.confirmTransaction(0);

        assertFalse(wallet.isOwner(owner2));
        assertEq(wallet.getOwnerCount(), 1);
    }

    function testFailNonOwnerSubmitTransaction() public {
        vm.prank(nonOwner);
        wallet.sendETH(owner2, 1 ether);
    }

    function testFailNonOwnerConfirmTransaction() public {
        vm.prank(owner1);
        wallet.sendETH(owner2, 1 ether);

        vm.prank(nonOwner);
        wallet.confirmTransaction(0);
    }

    function testFailDoubleConfirmation() public {
        vm.prank(owner1);
        wallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.confirmTransaction(0);
    }

    function testFailExecuteNonExistentTransaction() public {
        vm.prank(owner1);
        wallet.confirmTransaction(999);
    }

    function testFailRemoveNonOwner() public {
        vm.prank(owner1);
        wallet.removeOwner(nonOwner);
    }

    function testUpdateConfirmationsRequired() public {
        vm.prank(owner1);
        wallet.addOwner(owner3);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        assertEq(wallet.numNormalDecisionConfirmations(), 2);
        assertEq(wallet.numImportantDecisionConfirmations(), 2);
    }

    receive() external payable {}
}
