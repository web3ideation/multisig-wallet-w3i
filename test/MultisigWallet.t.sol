// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/MultisigWallet.sol";
import "../src/SimpleERC20.sol";
import "../src/SimpleERC721.sol";

contract MultisigWalletTest is Test {
    MultisigWallet public multisigWallet;
    SimpleERC20 public erc20Token;
    SimpleERC721 public erc721Token;
    address[] public owners;
    address[] public twoOwners;
    address[] public singleOwner;
    address[] public noOwners;
    address[] public invalidOwners;
    address[] public duplicateOwners;

    uint256 public constant INITIAL_BALANCE = 10 ether;
    uint256 public constant ERC20_INITIAL_SUPPLY = 1000000 * 10 ** 18;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public owner4 = address(4);
    address public owner5 = address(5);
    address public nonOwner = address(1000);

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

    event PendingTransactionsDeactivated();

    event ERC721Received(
        address indexed operator,
        address indexed from,
        uint256 indexed tokenId,
        bytes data
    );

    function setUp() public {
        owners = [owner1, owner2, owner3, owner4, owner5];
        twoOwners = [owner1, owner2];
        singleOwner = [owner1];
        invalidOwners = [address(0)];
        duplicateOwners = [address(1), address(1)];
        multisigWallet = new MultisigWallet(owners);
        erc20Token = new SimpleERC20(ERC20_INITIAL_SUPPLY);
        erc721Token = new SimpleERC721();

        vm.deal(address(multisigWallet), INITIAL_BALANCE);
        erc20Token.transfer(address(multisigWallet), 1000 * 10 ** 18);
        erc721Token.mint(address(multisigWallet), 1);
        erc721Token.mint(address(multisigWallet), 2);
    }

    function testDeposit() public {
        uint256 depositAmount = 1 ether;
        address depositor = address(0x123);
        vm.deal(depositor, depositAmount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(depositor, depositAmount, INITIAL_BALANCE + depositAmount);

        vm.prank(depositor);
        (bool success, ) = address(multisigWallet).call{value: depositAmount}(
            ""
        );
        require(success, "Deposit failed");

        assertEq(
            address(multisigWallet).balance,
            INITIAL_BALANCE + depositAmount
        );
    }

    function testAddOwner() public {
        address newOwner = address(0x123);

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.AddOwner,
            0,
            newOwner,
            0,
            "",
            address(0),
            0,
            owner1
        );
        vm.prank(owner1);
        multisigWallet.addOwner(newOwner);

        for (uint i = 1; i < (owners.length * 2 + 2) / 3 - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[(owners.length * 2 + 2) / 3], 0);
        vm.expectEmit(true, false, false, true);
        emit OwnerAdded(newOwner);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.AddOwner,
            0,
            newOwner,
            0,
            "",
            address(0),
            0,
            owners[(owners.length * 2 + 2) / 3]
        );
        vm.prank(owners[(owners.length * 2 + 2) / 3]);
        multisigWallet.confirmTransaction(0);

        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), 6);
    }

    function testRemoveOwner() public {
        // !!! so seems like the removal of an owner already happens too early, like not all -1 owners have to confirm the removal. check that if there is a logic error in the contract
        uint256 initialOwnerCount = multisigWallet.getOwnerCount();

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            owner5,
            0,
            "",
            address(0),
            0,
            owner1
        );
        vm.prank(owner1);
        multisigWallet.removeOwner(owner5);

        for (uint i = 1; i * 1000 < (owners.length * 1000 * 2) / 3; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);

            if (i * 1000 == (owners.length * 1000 * 2) / 3) {
                // This is the last confirmation, so expect the execution events
                vm.expectEmit(true, false, false, true);
                emit PendingTransactionsDeactivated();
                vm.expectEmit(true, false, false, true);
                emit OwnerRemoved(owner5);
                vm.expectEmit(true, true, true, true);
                emit ExecuteTransaction(
                    MultisigWallet.TransactionType.RemoveOwner,
                    0,
                    owner5,
                    0,
                    "",
                    address(0),
                    0,
                    owners[i]
                );
            }

            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check that owner5 is no longer an owner
        assertFalse(multisigWallet.isOwner(owner5));
        assertEq(multisigWallet.getOwnerCount(), initialOwnerCount - 1);

        // Check that owner5 can no longer confirm transactions
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(owner5);
        multisigWallet.confirmTransaction(0);

        // Check that trying to confirm the transaction again fails
        vm.expectRevert("MultisigWallet: Transaction not active");
        vm.prank(owners[0]);
        multisigWallet.confirmTransaction(0);
    }

    function testSubmitAndConfirmETHTransaction() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            amount,
            "",
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owner1
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ETH,
            recipient,
            amount,
            ""
        );

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            amount,
            "",
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owners[owners.length / 2]
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(recipient.balance, amount);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - amount);
    }

    function testSubmitAndConfirmERC20Transaction() public {
        address recipient = address(0x123);
        uint256 amount = 100 * 10 ** 18;

        uint256 initialBalance = erc20Token.balanceOf(address(multisigWallet));

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC20,
            0,
            recipient,
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount),
            address(erc20Token),
            amount,
            owner1
        );
        vm.prank(owner1);
        multisigWallet.transferERC20(
            IERC20(address(erc20Token)),
            recipient,
            amount
        );

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ERC20,
            0,
            recipient,
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount),
            address(erc20Token),
            amount,
            owners[owners.length / 2]
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(
            erc20Token.balanceOf(address(multisigWallet)),
            initialBalance - amount
        );
    }

    function testSubmitAndConfirmERC721Transaction() public {
        address recipient = address(0x123);
        uint256 tokenId = 1;

        assertEq(erc721Token.ownerOf(tokenId), address(multisigWallet));

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC721,
            0,
            recipient,
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(multisigWallet),
                recipient,
                tokenId
            ),
            address(erc721Token),
            tokenId,
            owner1
        );
        vm.prank(owner1);
        multisigWallet.safeTransferFromERC721(
            address(erc721Token),
            address(multisigWallet),
            recipient,
            tokenId
        );

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ERC721,
            0,
            recipient,
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(multisigWallet),
                recipient,
                tokenId
            ),
            address(erc721Token),
            tokenId,
            owners[owners.length / 2]
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(erc721Token.ownerOf(tokenId), recipient);
    }

    function testRevokeConfirmation() public {
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            payable(address(0x123)),
            1 ether,
            "",
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owner1
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ETH,
            payable(address(0x123)),
            1 ether,
            ""
        );

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit RevokeConfirmation(owner1, 0);
        vm.prank(owner1);
        multisigWallet.revokeConfirmation(0);

        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(address(0x123).balance, 0);
    }

    function testExecuteWithoutEnoughConfirmations2() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        // Confirm with less than required confirmations
        for (uint i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Attempt to execute the transaction
        vm.prank(owners[owners.length / 2]);
        vm.expectRevert(
            "MultisigWallet: insufficient confirmations to execute"
        );
        multisigWallet.executeTransaction(0);
    }

    function testGetOwners() public view {
        address[] memory currentOwners = multisigWallet.getOwners();
        assertEq(currentOwners.length, 5);
        for (uint i = 0; i < 5; i++) {
            assertEq(currentOwners[i], owners[i]);
        }
    }

    function testOtherTransaction() public {
        SimpleCounter counter = new SimpleCounter();

        bytes memory data = abi.encodeWithSignature("increment()");
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.Other,
            0,
            address(counter),
            0,
            data,
            address(0),
            0,
            owner1
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.Other,
            address(counter),
            0,
            data
        );

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.Other,
            0,
            address(counter),
            0,
            data,
            address(0),
            0,
            owners[owners.length / 2]
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(counter.count(), 1);
    }

    function testSendETH() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            amount,
            "",
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owner1
        );
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            amount,
            "",
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owners[owners.length / 2]
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(recipient.balance, amount);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - amount);
    }

    function testRevertWhenAddExistingOwner() public {
        vm.prank(owner1);
        multisigWallet.addOwner(address(0x123));

        for (uint i = 1; i < (owners.length * 2 + 2) / 3; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectRevert("MultisigWallet: owner already exists");
        vm.prank(owner1);
        multisigWallet.addOwner(address(0x123));
    }

    function testCannotRemoveLastOwnerAfterRemovals() public {
        // Initialize the multisig wallet with two owners
        multisigWallet = new MultisigWallet(twoOwners);

        // Remove owner2
        vm.prank(owner1);
        multisigWallet.removeOwner(owner2);

        uint txIndex = 0; // Since it's the first transaction

        // Confirm the transaction with owner2
        vm.prank(owner2);
        multisigWallet.confirmTransaction(txIndex);

        // Now, only owner1 remains. Attempt to remove owner1
        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: cannot remove the last owner");
        multisigWallet.removeOwner(owner1);
    }

    function testNonOwnerSubmitTransaction() public {
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(nonOwner);
        multisigWallet.sendETH(owner2, 1 ether);
    }

    function testNonOwnerConfirmTransaction() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(nonOwner);
        multisigWallet.confirmTransaction(0);
    }

    function testDoubleConfirmation() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.expectRevert(
            "MultisigWallet: transaction already confirmed by this owner"
        );
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
    }

    function testExecuteNonExistentTransaction() public {
        vm.expectRevert("MultisigWallet: Transaction does not exist");
        vm.prank(owner1);
        multisigWallet.confirmTransaction(999);
    }

    function testRemoveNonOwner() public {
        vm.expectRevert("MultisigWallet: address is not an owner");
        vm.prank(owner1);
        multisigWallet.removeOwner(nonOwner);
    }

    function testAddOwnerWithDynamicConfirmations() public {
        uint numOwners = 100; // set the number of Owners
        uint confirmations = 67; // set the nunber of Confirmations
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses to owners
        }

        // Initialize a new multisig wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        address newOwner = address(0x123);

        // Emit the event for submitting the add owner transaction
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.AddOwner,
            0,
            newOwner,
            0,
            "",
            address(0),
            0,
            dynamicOwners[0]
        );
        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        // Loop through to confirm the transaction until reaching the required confirmations (2/3 + 1)
        for (uint i = 1; i < confirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation that triggers the execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[confirmations - 1], 0);
        vm.expectEmit(true, false, false, true);
        emit OwnerAdded(newOwner);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.AddOwner,
            0,
            newOwner,
            0,
            "",
            address(0),
            0,
            dynamicOwners[confirmations - 1]
        );
        vm.prank(dynamicOwners[confirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Check that the new owner is indeed added
        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), numOwners + 1);
    }

    function testFuzzAddOwnerWithDynamicConfirmations(uint numOwners) public {
        // Limit the number of owners to 120 for fuzzing
        numOwners = bound(numOwners, 3, 120); // Minimum of 3 owners to ensure at least 2/3 logic works

        // Dynamically calculate required confirmations (2/3 of numOwners)
        uint requiredConfirmations = (numOwners * 2 + 2) / 3; // This gives us 2/3 + 1 confirmation threshold

        address[] memory dynamicOwners = new address[](numOwners);
        for (uint i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses to owners
        }

        // Initialize a new multisig wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        address newOwner = address(0x123);

        // Emit the event for submitting the add owner transaction
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.AddOwner,
            0,
            newOwner,
            0,
            "",
            address(0),
            0,
            dynamicOwners[0]
        );
        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        // Loop through to confirm the transaction until reaching the required confirmations (2/3 + 1)
        for (uint i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation that triggers the execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);
        vm.expectEmit(true, false, false, true);
        emit OwnerAdded(newOwner);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.AddOwner,
            0,
            newOwner,
            0,
            "",
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1]
        );
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Check that the new owner is indeed added
        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), numOwners + 1);
    }

    function testSingleOwnerCanAddAnother() public {
        uint numOwners = 1;
        address[] memory dynamicOwners = new address[](numOwners);
        dynamicOwners[0] = address(uint160(1));

        multisigWallet = new MultisigWallet(dynamicOwners);
        address newOwner = address(0x123);

        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        // Check if the new owner was successfully added
        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), numOwners + 1);
    }

    /// @notice Test that removing an owner with two owners requires both to confirm.
    function testTwoOwnersMustConfirmRemoval() public {
        // Initialize a new multisig wallet with two owners using a dynamic array
        multisigWallet = new MultisigWallet(twoOwners);

        address ownerToRemove = owner2;
        address initiator = owner1;

        // Expect the SubmitTransaction event
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            ownerToRemove,
            0,
            "",
            address(0),
            0,
            initiator
        );
        vm.prank(initiator);
        multisigWallet.removeOwner(ownerToRemove);

        // At this point, the transaction has 1 confirmation (from initiator)

        // Expect the ConfirmTransaction event from the second owner
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);

        // Expect the OwnerRemoved and ExecuteTransaction events upon confirmation
        vm.expectEmit(true, false, false, true);
        emit OwnerRemoved(ownerToRemove);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            ownerToRemove,
            0,
            "",
            address(0),
            0,
            owner2
        );

        // Second owner confirms the transaction
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Verify that ownerToRemove has been removed
        assertFalse(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), 1);
    }

    function testRemoveOwnerWithDynamicConfirmations() public {
        uint256 numOwners = 10;
        uint256 requiredConfirmations = (numOwners * 2 + 2) / 3; // Ceiling of 2/3 * numOwners

        // Initialize dynamic owners
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        // Initialize a new multisig wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        address ownerToRemove = dynamicOwners[numOwners - 1]; // Last owner
        address initiator = dynamicOwners[0];

        // Expect the SubmitTransaction event for RemoveOwner
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            ownerToRemove,
            0,
            "",
            address(0),
            0,
            initiator
        );
        vm.prank(initiator);
        multisigWallet.removeOwner(ownerToRemove);

        // Confirm the transaction with the required number of owners minus one
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation that triggers the execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect PendingTransactionsDeactivated event
        vm.expectEmit(true, false, false, true);
        emit PendingTransactionsDeactivated();

        // Expect OwnerRemoved event
        vm.expectEmit(true, true, true, false);
        emit OwnerRemoved(ownerToRemove);

        // Expect ExecuteTransaction event
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            ownerToRemove,
            0,
            "",
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1]
        );

        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the owner has been removed
        assertFalse(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), numOwners - 1);
    }

    function testFuzzRemoveOwnerWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // Bound the number of owners between 3 and 120 to ensure meaningful tests
        uint256 numOwners = bound(numOwnersInput, 3, 120);
        uint256 requiredConfirmations = (numOwners * 2 + 2) / 3; // Ceiling of 2/3 * numOwners

        // Initialize dynamic owners
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        // Initialize a new multisig wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        address ownerToRemove = dynamicOwners[numOwners - 1]; // Last owner
        address initiator = dynamicOwners[0];

        // Expect the SubmitTransaction event for RemoveOwner
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            ownerToRemove,
            0,
            "",
            address(0),
            0,
            initiator
        );
        vm.prank(initiator);
        multisigWallet.removeOwner(ownerToRemove);

        // Confirm the transaction with the required number of owners minus one
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation that triggers the execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect PendingTransactionsDeactivated event
        vm.expectEmit(true, false, false, true);
        emit PendingTransactionsDeactivated();

        // Expect OwnerRemoved event
        vm.expectEmit(true, true, true, false);
        emit OwnerRemoved(ownerToRemove);

        // Expect ExecuteTransaction event
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.RemoveOwner,
            0,
            ownerToRemove,
            0,
            "",
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1]
        );

        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the owner has been removed
        assertFalse(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), numOwners - 1);
    }

    /// @notice Test that attempting to remove the last remaining owner fails.
    function testRemoveLastOwner2() public {
        // Initialize a new multisig wallet with one owner
        multisigWallet = new MultisigWallet(singleOwner);

        address ownerToRemove = owner1;

        // Attempt to remove the only owner
        vm.prank(ownerToRemove);
        vm.expectRevert("MultisigWallet: cannot remove the last owner");
        multisigWallet.removeOwner(ownerToRemove);
    }

    /// @notice Test that a non-owner cannot remove an owner.
    function testNonOwnerCannotRemoveOwner() public {
        // Initialize a new multisig wallet with two owners
        multisigWallet = new MultisigWallet(twoOwners);

        address ownerToRemove = owner2;
        address nonOwnerAddress = nonOwner;

        // Attempt to remove an owner from a non-owner account
        vm.prank(nonOwnerAddress);
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        multisigWallet.removeOwner(ownerToRemove);
    }

    /// @notice Test that removing a non-existent owner reverts.
    function testRemoveNonExistentOwner() public {
        // Initialize a new multisig wallet with two owners
        multisigWallet = new MultisigWallet(twoOwners);

        address nonExistentOwner = owner3; // Assuming owner3 was not added
        address initiator = owner1;

        // Attempt to remove a non-existent owner
        vm.prank(initiator);
        vm.expectRevert("MultisigWallet: address is not an owner");
        multisigWallet.removeOwner(nonExistentOwner);
    }

    function testMaliciousOtherTransactionCannotAddOwner() public {
        // Define the malicious owner and the new owner to be added
        address maliciousOwner = owner1;
        address newOwner = address(0x999);

        // Encode the calldata to call addOwner(newOwner)
        bytes memory payload = abi.encodeWithSignature(
            "addOwner(address)",
            newOwner
        );

        // Expect the SubmitTransaction event to be emitted
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.Other,
            0, // txIndex will be 0 as it's the first transaction
            address(multisigWallet), // to address is the MultisigWallet itself
            0, // value is 0 for function calls
            payload, // data is the encoded addOwner call
            address(0), // tokenAddress is 0 for "Other" transactions
            0, // amountOrTokenId is 0 for "Other" transactions
            maliciousOwner // owner who submitted the transaction
        );

        // Prank as the malicious owner and submit the "Other" transaction
        vm.prank(maliciousOwner);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.Other,
            address(multisigWallet), // to address is the MultisigWallet itself
            0, // value is 0 for function calls
            payload // data is the encoded addOwner call
        );

        // At this point, the transaction has 1 confirmation from the maliciousOwner
        // For a 5-owner setup, >50% confirmations require 3 confirmations

        // Owner2 confirms the transaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Owner3 attempts to confirm the transaction, which should trigger execution
        // Since the transaction type is "Other" and only >50% confirmations are met,
        // executeTransaction will attempt to call addOwner, which should fail
        vm.expectRevert("MultisigWallet: cannot call internal functions");
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner3, 0);
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);

        // After the revert, verify that the new owner was not added
        assertFalse(
            multisigWallet.isOwner(newOwner),
            "New owner should not be added"
        );
        assertEq(
            multisigWallet.getOwnerCount(),
            5,
            "Owner count should remain unchanged"
        );
    }

    function testMaliciousOtherTransactionCannotRemoveOwner() public {
        // Define the malicious owner and the owner to be removed
        address maliciousOwner = owner1;
        address ownerToRemove = owner5;

        // Encode the calldata to call removeOwner(ownerToRemove)
        bytes memory payload = abi.encodeWithSignature(
            "removeOwner(address)",
            ownerToRemove
        );

        // Expect the SubmitTransaction event to be emitted
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.Other, // TransactionType.Other
            0, // txIndex (first transaction)
            address(multisigWallet), // to address is the MultisigWallet itself
            0, // value is 0 for function calls
            payload, // data is the encoded removeOwner call
            address(0), // tokenAddress is 0 for "Other" transactions
            0, // amountOrTokenId is 0 for "Other" transactions
            maliciousOwner // owner who submitted the transaction
        );

        // Prank as the malicious owner and submit the "Other" transaction
        vm.prank(maliciousOwner);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.Other, // TransactionType.Other
            address(multisigWallet), // to address is the MultisigWallet itself
            0, // value is 0 for function calls
            payload // data is the encoded removeOwner call
        );

        // At this point, the transaction has 1 confirmation from the maliciousOwner
        // For a 5-owner setup, >50% confirmations require 3 confirmations

        // Owner2 confirms the transaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Owner3 attempts to confirm the transaction, which should trigger execution
        // Since the transaction type is "Other" and only >50% confirmations are met,
        // executeTransaction will attempt to call removeOwner, which should fail
        vm.expectRevert("MultisigWallet: cannot call internal functions"); // Expect the execution to revert
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner3, 0);
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);

        // After the revert, verify that the owner was not removed
        assertTrue(
            multisigWallet.isOwner(ownerToRemove),
            "Owner should not be removed"
        );
        assertEq(
            multisigWallet.getOwnerCount(),
            5,
            "Owner count should remain unchanged"
        );
    }

    function testFuzzSendETHWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // **Step 1: Bound the Number of Owners**
        // Ensure the number of owners is between 3 and 120 to maintain meaningful >50% confirmation logic
        uint256 numOwners = bound(numOwnersInput, 3, 120);

        // **Step 2: Calculate Required Confirmations**
        // For >50%, requiredConfirmations = floor(numOwners / 2) + 1
        uint256 requiredConfirmations = (numOwners / 2) + 1;

        // **Step 3: Initialize Dynamic Owners**
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses
        }

        // **Step 4: Deploy a New Multisig Wallet with Dynamic Owners**
        multisigWallet = new MultisigWallet(dynamicOwners);

        // **Step 5: Fund the Multisig Wallet with ETH**
        uint256 initialBalance = 10 ether;
        vm.deal(address(multisigWallet), initialBalance);
        assertEq(
            address(multisigWallet).balance,
            initialBalance,
            "Initial balance mismatch"
        );

        // **Step 6: Define Recipient and Transfer Amount**
        address payable recipient = payable(address(0xABC));
        uint256 transferAmount = 1 ether;

        // **Ensure Recipient Starts with Zero Balance**
        assertEq(
            recipient.balance,
            0,
            "Recipient should start with zero balance"
        );

        // **Step 7: Submit the ETH Transfer Transaction**
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0, // txIndex will be 0 as it's the first transaction
            recipient,
            transferAmount,
            "",
            address(0),
            0,
            dynamicOwners[0] // Initiator
        );
        vm.prank(dynamicOwners[0]); // Initiate from the first owner
        multisigWallet.sendETH(recipient, transferAmount);

        // **Step 8: Confirm the Transaction with Required Confirmations**
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // **Step 9: Final Confirmation to Trigger Execution**
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        vm.expectEmit(true, false, false, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            transferAmount,
            "",
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1] // Executor
        );

        vm.prank(dynamicOwners[requiredConfirmations - 1]); // Final confirmer
        multisigWallet.confirmTransaction(0);

        // **Step 10: Assertions to Ensure Correct Execution**
        assertEq(
            recipient.balance,
            transferAmount,
            "Recipient should receive the ETH transfer"
        );
        assertEq(
            address(multisigWallet).balance,
            initialBalance - transferAmount,
            "Wallet balance should decrease by transfer amount"
        );

        // **Optional: Ensure Transaction is Marked as Inactive**
        // You can add a getter or access the transactions array directly if accessible
        // Example (if transactions are accessible):
        // Transaction memory txn = multisigWallet.transactions(0);
        // assertFalse(txn.isActive, "Transaction should be inactive after execution");
    }

    function testFuzzERC20TransferWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // **Step 1: Bound the Number of Owners**
        uint256 numOwners = bound(numOwnersInput, 3, 120);
        uint256 requiredConfirmations = (numOwners / 2) + 1;

        // **Step 2: Initialize Dynamic Owners**
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        // **Step 3: Deploy MultisigWallet and ERC20 Token**
        multisigWallet = new MultisigWallet(dynamicOwners);
        SimpleERC20 dynamicERC20 = new SimpleERC20(1_000_000 * 10 ** 18); // 1,000,000 tokens
        dynamicERC20.transfer(address(multisigWallet), 100_000 * 10 ** 18); // Transfer 100,000 tokens to the wallet

        // **Step 4: Define Recipient and Transfer Amount**
        address recipient = address(0xABC); // Arbitrary recipient address
        uint256 transferAmount = 10_000 * 10 ** 18; // 10,000 tokens

        // **Assert Initial Balances**
        assertEq(
            dynamicERC20.balanceOf(recipient),
            0,
            "Initial recipient balance should be zero"
        );
        assertEq(
            dynamicERC20.balanceOf(address(multisigWallet)),
            100_000 * 10 ** 18,
            "Initial wallet balance incorrect"
        );

        // **Step 5: Prepare the ERC20 Transfer Data**
        bytes memory transferData = abi.encodeWithSelector(
            dynamicERC20.transfer.selector,
            recipient,
            transferAmount
        );

        // **Step 6: Expect SubmitTransaction Event**
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC20,
            0, // txIndex
            recipient,
            0, // value (0 for ERC20 transfers)
            transferData,
            address(dynamicERC20),
            transferAmount,
            dynamicOwners[0] // Initiator
        );

        // **Step 7: Expect ConfirmTransaction Event from Submitter**
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[0], 0);

        // **Step 8: Submit the ERC20 Transfer Transaction**
        vm.prank(dynamicOwners[0]); // Initiate from the first owner
        multisigWallet.transferERC20(
            IERC20(address(dynamicERC20)),
            recipient,
            transferAmount
        );

        // **Step 9: Confirm the Transaction with Required Confirmations - 1**
        // Since the first confirmation is already done by the submitter
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // **Step 10: Final Confirmation to Trigger Execution**
        // The last confirmation should trigger the execution
        vm.expectEmit(true, false, false, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ERC20,
            0,
            recipient,
            0, // value (0 for ERC20 transfers)
            transferData,
            address(dynamicERC20),
            transferAmount,
            dynamicOwners[requiredConfirmations - 1] // Executor
        );

        vm.prank(dynamicOwners[requiredConfirmations - 1]); // Final confirmer
        multisigWallet.confirmTransaction(0);

        // **Step 11: Assertions to Ensure Correct Execution**
        // Verify that the recipient's ERC20 balance has increased by the transfer amount
        assertEq(
            dynamicERC20.balanceOf(recipient),
            transferAmount,
            "Recipient should receive the ERC20 transfer"
        );

        // Verify that the Multisig Wallet's ERC20 balance has decreased accordingly
        assertEq(
            dynamicERC20.balanceOf(address(multisigWallet)),
            100_000 * 10 ** 18 - transferAmount,
            "Wallet ERC20 balance should decrease by transfer amount"
        );
    }

    function testFuzzERC721TransferWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // **Step 1: Bound the Number of Owners**
        // Ensure the number of owners is between 3 and 120 to maintain meaningful >50% confirmation logic
        uint256 numOwners = bound(numOwnersInput, 3, 120);

        // **Step 2: Calculate Required Confirmations**
        // For >50%, requiredConfirmations = floor(numOwners / 2) + 1
        uint256 requiredConfirmations = (numOwners / 2) + 1;

        // **Step 3: Initialize Dynamic Owners**
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses
        }

        // **Step 4: Deploy MultisigWallet and ERC721 Token**
        multisigWallet = new MultisigWallet(dynamicOwners);
        SimpleERC721 dynamicERC721 = new SimpleERC721();

        uint256 tokenId = 1; // Define a tokenId to transfer

        // **Step 5: Mint ERC721 Token to the MultisigWallet**
        dynamicERC721.mint(address(multisigWallet), tokenId);
        assertEq(
            dynamicERC721.ownerOf(tokenId),
            address(multisigWallet),
            "ERC721 token not minted to wallet"
        );

        // **Step 6: Define Recipient and Token ID**
        address recipient = address(0xABC); // Arbitrary recipient address

        // **Step 7: Prepare the ERC721 Transfer Data**
        bytes memory transferData = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(multisigWallet),
            recipient,
            tokenId
        );

        // **Step 8: Submit the ERC721 Transfer Transaction**
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC721,
            0, // txIndex will be 0 as it's the first transaction
            recipient,
            0, // value is 0 for ERC721 transfers
            transferData,
            address(dynamicERC721),
            tokenId,
            dynamicOwners[0] // Initiator
        );

        // **Step 9: Submit the Transaction via transferERC721**
        vm.prank(dynamicOwners[0]); // Initiate from the first owner
        multisigWallet.safeTransferFromERC721(
            address(dynamicERC721),
            address(multisigWallet),
            recipient,
            tokenId
        );

        // **Step 10: Confirm the Transaction with Required Confirmations - 1**
        // Since the first confirmation is already done by the submitter (confirmTransaction is called inside submitTransaction)
        // Hence, we need to confirm with (requiredConfirmations - 1) additional owners

        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // **Step 11: Final Confirmation to Trigger Execution**
        // The last confirmation should trigger the execution
        vm.expectEmit(true, false, false, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ERC721,
            0, // txIndex
            recipient,
            0, // value is 0 for ERC721 transfers
            transferData,
            address(dynamicERC721),
            tokenId,
            dynamicOwners[requiredConfirmations - 1] // Executor
        );

        vm.prank(dynamicOwners[requiredConfirmations - 1]); // Final confirmer
        multisigWallet.confirmTransaction(0);

        // **Step 12: Assertions to Ensure Correct Execution**
        // Verify that the recipient now owns the ERC721 token
        assertEq(
            dynamicERC721.ownerOf(tokenId),
            recipient,
            "ERC721 token was not transferred to the recipient"
        );

        // Verify that the Multisig Wallet no longer owns the token
        assertEq(
            dynamicERC721.ownerOf(tokenId),
            recipient,
            "MultisigWallet still owns the ERC721 token after transfer"
        );

        // No further confirmations should be attempted after execution
    }

    // 1. Test Constructor Validations

    function testConstructorRevertsWithNoOwners() public {
        vm.expectRevert("MultisigWallet: at least one owner required");
        new MultisigWallet(noOwners);
    }

    function testConstructorRevertsWithZeroAddressOwner() public {
        vm.expectRevert("MultisigWallet: owner address cannot be zero");
        new MultisigWallet(invalidOwners);
    }

    function testConstructorRevertsWithDuplicateOwners() public {
        vm.expectRevert("MultisigWallet: duplicate owner address");
        new MultisigWallet(duplicateOwners);
    }

    // 2. Test Transaction Submission Validations

    function testSubmitETHTransactionWithZeroValue() public {
        address recipient = address(0x123);
        vm.expectRevert("MultisigWallet: Ether (Wei) amount required");
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, 0);
    }

    function testSubmitERC20TransactionWithEmptyData() public {
        bytes memory emptyData = "";

        vm.expectRevert(
            "MultisigWallet: invalid data length for ERC20 transfer"
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ERC20,
            address(erc20Token),
            0,
            emptyData
        );
    }

    // 3. Test Confirmation and Execution Errors

    function testDoubleConfirmationReverts() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        vm.expectRevert(
            "MultisigWallet: transaction already confirmed by this owner"
        );
        multisigWallet.confirmTransaction(0);
    }

    function testExecuteWithoutEnoughConfirmations() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        // Initiate the ETH transfer from owner1 (this auto-confirms by owner1)
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        // Confirm the transaction with only owner2 (total 2 confirmations out of 5)
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Attempt to execute the transaction with owner3, expecting a revert
        vm.expectRevert(
            "MultisigWallet: insufficient confirmations to execute"
        );
        vm.prank(owner3);
        multisigWallet.executeTransaction(0);

        // Verify that the transaction was not executed
        assertEq(
            recipient.balance,
            0,
            "Recipient should not have received ETH"
        );
        assertEq(
            address(multisigWallet).balance,
            INITIAL_BALANCE,
            "Wallet balance should remain unchanged"
        );
    }

    // 4. Test Data Decoding Errors

    function testMalformedERC20TransferData() public {
        address recipient = address(0x123);
        // Incorrect data length (e.g., missing bytes)
        bytes memory malformedData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            recipient
        );

        vm.expectRevert(
            "MultisigWallet: invalid data length for ERC20 transfer"
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ERC20,
            address(erc20Token),
            0,
            malformedData
        );
    }

    function testMalformedERC721TransferData() public {
        address from = address(multisigWallet);
        address to = address(0x123);
        // Incorrect data length (e.g., missing tokenId)
        bytes memory malformedData = abi.encodeWithSignature(
            "safeTransferFrom(address,address)",
            from,
            to
        );

        vm.expectRevert(
            "MultisigWallet: invalid data length for ERC721 transfer"
        );

        // Use the submitTransaction directly to pass the malformed data
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ERC721,
            address(erc721Token),
            0,
            malformedData // Pass the malformed data here
        );
    }

    // 5. Test Owner Management Edge Cases

    function testAddExistingOwnerReverts() public {
        address existingOwner = owner1;

        vm.prank(owner2);
        vm.expectRevert("MultisigWallet: owner already exists");
        multisigWallet.addOwner(existingOwner);
    }

    function testRemoveNonExistentOwnerReverts() public {
        address nonExistentOwner = address(0x999);

        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: address is not an owner");
        multisigWallet.removeOwner(nonExistentOwner);
    }

    function testRemoveLastOwnerReverts() public {
        // Initialize with single owner
        multisigWallet = new MultisigWallet(singleOwner);

        address soleOwner = owner1;

        vm.prank(soleOwner);
        vm.expectRevert("MultisigWallet: cannot remove the last owner");
        multisigWallet.removeOwner(soleOwner);
    }

    // 6. Test Reentrancy and Security Guards

    function testReentrancyAtttackOnConfirmTransation() public {
        // Deploy a malicious contract that attempts to re-enter
        MaliciousContract attacker = new MaliciousContract(
            payable(address(multisigWallet)) // Cast to payable
        );

        // Fund the wallet with ETH
        vm.deal(address(multisigWallet), 10 ether);

        // Submit a transaction that sends ETH to the attacker, triggering reentrancy
        vm.prank(owner1);
        multisigWallet.sendETH(address(attacker), 1 ether);

        // Confirm the transaction
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Expect reentrancy guard to prevent the attack
        vm.expectRevert("MultisigWallet: external call failed");
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);
    }

    function testReentrancyAttackOnExecuteTransaction() public {
        // Deploy the malicious contract
        MaliciousReentrantExecutor attacker = new MaliciousReentrantExecutor(
            multisigWallet
        );

        // Fund the multisig wallet
        vm.deal(address(multisigWallet), 10 ether);

        // Have the multisig owners submit and confirm a transaction to send ETH to the attacker
        vm.prank(owner1);
        multisigWallet.sendETH(address(attacker), 1 ether);

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation and attempt to execute, which should trigger the reentrancy attack
        vm.prank(owners[owners.length / 2]);
        vm.expectRevert("MultisigWallet: external call failed");
        multisigWallet.confirmTransaction(0);
    }

    function testOnERC721Received() public {
        // Arrange
        address from = owner2; // The current owner of the token
        uint256 tokenId = 3; // Use a unique tokenId
        bytes memory data = "some data";

        // Mint a token to 'from' (owner2)
        // 'address(this)' is the owner of the SimpleERC721 contract in this test context
        erc721Token.mint(from, tokenId);

        // Expect the ERC721Received event to be emitted when the token is received
        vm.expectEmit(true, true, true, true);
        emit ERC721Received(from, from, tokenId, data);

        // Act: Transfer the token from 'from' to the multisig wallet
        vm.prank(from); // Sets msg.sender to 'from', making 'from' the operator
        erc721Token.safeTransferFrom(
            from,
            address(multisigWallet),
            tokenId,
            data
        );

        // Assert: Verify that the multisig wallet now owns the token
        assertEq(
            erc721Token.ownerOf(tokenId),
            address(multisigWallet),
            "Token ownership not transferred correctly"
        );
    }

    function testReceiveERC20Tokens() public {
        // Arrange
        address sender = owner1;
        uint256 transferAmount = 500 * 10 ** 18; // 500 ERC20 tokens

        // **Transfer tokens to sender (owner1)**
        bool success = erc20Token.transfer(sender, transferAmount);
        require(success, "ERC20 transfer to sender failed");

        uint256 initialWalletBalance = erc20Token.balanceOf(
            address(multisigWallet)
        );

        // Ensure the sender has enough tokens
        uint256 senderBalance = erc20Token.balanceOf(sender);
        assertGe(
            senderBalance,
            transferAmount,
            "Sender does not have enough ERC20 tokens"
        );

        // Act: Transfer ERC20 tokens to the MultisigWallet
        vm.prank(sender);
        success = erc20Token.transfer(address(multisigWallet), transferAmount);
        require(success, "ERC20 transfer failed");

        // Assert: Check that the MultisigWallet's ERC20 balance has increased by transferAmount
        uint256 finalWalletBalance = erc20Token.balanceOf(
            address(multisigWallet)
        );
        assertEq(
            finalWalletBalance,
            initialWalletBalance + transferAmount,
            "ERC20 tokens not received correctly by MultisigWallet"
        );

        // Optionally, verify that the sender's balance has decreased by transferAmount
        uint256 finalSenderBalance = erc20Token.balanceOf(sender);
        assertEq(
            senderBalance - finalSenderBalance,
            transferAmount,
            "Sender's ERC20 balance did not decrease correctly"
        );
    }
}

// Malicious contract that attempts a reentrancy attack
contract MaliciousContract {
    MultisigWallet public target;

    constructor(address payable _target) {
        target = MultisigWallet(_target);
    }

    receive() external payable {
        // Attempt to re-enter the executeTransaction function
        target.confirmTransaction(0);
    }
}

// Malicious contract attempting to re-enter executeTransaction
contract MaliciousReentrantExecutor {
    MultisigWallet public target;

    constructor(MultisigWallet _target) {
        target = _target;
    }

    receive() external payable {
        // Attempt to re-enter executeTransaction
        target.executeTransaction(0);
    }
}

// Simple counter contract for testing "Other" transaction type
contract SimpleCounter {
    uint public count;

    function increment() public {
        count += 1;
    }
}
