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
    uint256 public constant INITIAL_BALANCE = 10 ether;
    uint256 public constant ERC20_INITIAL_SUPPLY = 1000000 * 10 ** 18;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public owner4 = address(4);
    address public owner5 = address(5);
    address public nonOwner = address(100);

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
        owners = [owner1, owner2, owner3, owner4, owner5];
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
                // vm.expectEmit(true, false, false, true);
                // emit PendingTransactionsDeactivated(); // !!! Why do i get a compilation error here??
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
        vm.expectRevert("Not a multisig owner");
        vm.prank(owner5);
        multisigWallet.confirmTransaction(0);

        // Check that trying to confirm the transaction again fails
        vm.expectRevert("Transaction not active");
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
        multisigWallet.safeTransferERC20(
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
        multisigWallet.transferERC721(
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

    function testFailExecuteWithInsufficientConfirmations() public {
        // !!! double check this with the "Fail" in the name maybe the test is not working correctly
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ETH,
            recipient,
            amount,
            ""
        );

        for (uint i = 0; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        assertEq(recipient.balance, 0);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE);

        vm.expectRevert("Not enough confirmations");
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(recipient.balance, 0);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE);
    }

    function testGetOwners() public {
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

        vm.expectRevert("Owner already exists");
        vm.prank(owner1);
        multisigWallet.addOwner(address(0x123));
    }

    function testFailRemoveLastOwner() public {
        // so is the "fail" keyword here a problem?

        // Remove all owners except two
        for (uint i = 2; i < owners.length; i++) {
            vm.prank(owner1);
            multisigWallet.removeOwner(owners[i]);

            for (uint j = 0; j < (owners.length * 2 + 2) / 3; j++) {
                vm.prank(owners[j]);
                multisigWallet.confirmTransaction(i - 2);
            }
        }

        // Try to remove the second-to-last owner
        vm.prank(owner1);
        multisigWallet.removeOwner(owner2);

        for (uint j = 0; j < (owners.length * 2 + 2) / 3; j++) {
            vm.prank(owners[j]);
            multisigWallet.confirmTransaction(owners.length - 2);
        }

        // Try to remove the last owner (should fail)
        vm.prank(owner1);
        vm.expectRevert("Cannot remove last owner");
        multisigWallet.removeOwner(owner1);
    }

    function testNonOwnerSubmitTransaction() public {
        vm.expectRevert("Not a multisig owner");
        vm.prank(nonOwner);
        multisigWallet.sendETH(owner2, 1 ether);
    }

    function testNonOwnerConfirmTransaction() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.expectRevert("Not a multisig owner");
        vm.prank(nonOwner);
        multisigWallet.confirmTransaction(0);
    }

    function testDoubleConfirmation() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.expectRevert("Transaction already confirmed");
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
    }

    function testExecuteNonExistentTransaction() public {
        vm.expectRevert("Transaction does not exist");
        vm.prank(owner1);
        multisigWallet.confirmTransaction(999);
    }

    function testRemoveNonOwner() public {
        vm.expectRevert("Not an owner");
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
}

// Simple counter contract for testing "Other" transaction type
contract SimpleCounter {
    uint public count;

    function increment() public {
        count += 1;
    }
}
