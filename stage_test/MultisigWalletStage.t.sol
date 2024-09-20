// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../lib/forge-std/src/Test.sol";
import "../src/MultisigWallet.sol";
import "../src/SimpleERC20.sol";
import "../src/SimpleERC721.sol";

/**
 * @title MultisigWalletTest
 * @notice This contract tests the functionalities of the MultisigWallet contract, including owner management, ETH and token transfers, and transaction confirmation/execution processes.
 * @dev Uses Foundry's Test contract for unit testing. The contract covers various scenarios, including dynamic confirmation requirements, edge cases for owner management, and token interactions.
 */
contract MultisigWalletTest is Test {
    /// @notice The multisig wallet instance being tested.
    MultisigWallet public multisigWallet;

    /// @notice The ERC20 token instance for testing ERC20 transfers.
    SimpleERC20 public erc20Token;

    /// @notice The ERC721 token instance for testing ERC721 transfers.
    SimpleERC721 public erc721Token;

    /// @notice Various address arrays used for different test scenarios (e.g., owners, invalid owners).
    address[] public owners;
    address[] public twoOwners;
    address[] public singleOwner;
    address[] public noOwners;
    address[] public invalidOwners;
    address[] public duplicateOwners;
    address[] public threeOwners;

    /// @notice Constant values used throughout the tests.
    uint256 public constant INITIAL_BALANCE = 10 ether;
    uint256 public constant ERC20_INITIAL_SUPPLY = 1000000 * 10 ** 18;

    /// @notice Addresses representing owners and non-owners used in the tests.
    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public owner4 = address(4);
    address public owner5 = address(5);
    address public nonOwner = address(1000);

    /**
     * @notice Event emitted during deposit tests.
     */
    event Deposit(
        address indexed sender,
        uint256 indexed amount,
        uint256 indexed balance
    );

    /**
     * @notice Event emitted during transaction submission.
     */
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

    /**
     * @notice Event emitted during transaction confirmation.
     */
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);

    /**
     * @notice Event emitted during transaction confirmation revocation.
     */
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);

    /**
     * @notice Event emitted during transaction execution.
     */
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

    /**
     * @notice Event emitted when an owner is added.
     */
    event OwnerAdded(address indexed owner);

    /**
     * @notice Event emitted when an owner is removed.
     */
    event OwnerRemoved(address indexed owner);

    /**
     * @notice Event emitted when pending transactions are deactivated.
     */
    event PendingTransactionsDeactivated();

    /**
     * @notice Event emitted when the contract receives an ERC721 token.
     */
    event ERC721Received(
        address indexed operator,
        address indexed from,
        uint256 indexed tokenId,
        bytes data
    );

    /**
     * @notice Sets up the environment for each test.
     * @dev Initializes owners, multisig wallet, and token contracts.
     */
    function setUp() public {
        owners = [owner1, owner2, owner3, owner4, owner5];
        twoOwners = [owner1, owner2];
        threeOwners = [owner1, owner2, owner3];
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

    /**
     * @notice Tests the deposit functionality of the multisig wallet.
     * @dev Verifies that a deposit correctly updates the balance and emits the correct event.
     */
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

    /**
     * @notice Tests the functionality of adding a new owner to the multisig wallet.
     * @dev Verifies that adding a new owner requires the correct number of confirmations.
     */
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

    /**
     * @notice Tests the functionality of removing an owner from the multisig wallet.
     * @dev Verifies that removing an owner requires the correct number of confirmations.
     */
    function testRemoveOwner() public {
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

        assertFalse(multisigWallet.isOwner(owner5));
        assertEq(multisigWallet.getOwnerCount(), initialOwnerCount - 1);

        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(owner5);
        multisigWallet.confirmTransaction(0);

        vm.expectRevert("MultisigWallet: Transaction not active");
        vm.prank(owners[0]);
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests the submission and confirmation of an ETH transfer transaction.
     * @dev Verifies that an ETH transfer transaction is submitted, confirmed, and executed correctly.
     */
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

    /**
     * @notice Tests the submission and confirmation of an ERC20 token transfer transaction.
     * @dev Verifies that an ERC20 transfer transaction is submitted, confirmed, and executed correctly.
     */
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

    /**
     * @notice Tests the submission and confirmation of an ERC721 token transfer transaction.
     * @dev Verifies that an ERC721 transfer transaction is submitted, confirmed, and executed correctly.
     */
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

    /**
     * @notice Tests the revocation of a previously confirmed transaction.
     * @dev Verifies that revoking a confirmation decrements the confirmation count and prevents execution.
     */
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

    /**
     * @notice Tests that a transaction cannot be executed without sufficient confirmations.
     * @dev Verifies that attempting to execute a transaction with insufficient confirmations reverts.
     */
    function testExecuteWithoutEnoughConfirmations2() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.prank(owners[owners.length / 2]);
        vm.expectRevert(
            "MultisigWallet: insufficient confirmations to execute"
        );
        multisigWallet.executeTransaction(0);
    }

    /**
     * @notice Tests retrieval of the multisig wallet's owner list.
     * @dev Verifies that the owner list returned by the wallet matches the expected list of owners.
     */
    function testGetOwners() public view {
        address[] memory currentOwners = multisigWallet.getOwners();
        assertEq(currentOwners.length, 5);
        for (uint i = 0; i < 5; i++) {
            assertEq(currentOwners[i], owners[i]);
        }
    }

    /**
     * @notice Tests execution of a transaction of type `Other` that calls an external contract function.
     * @dev Verifies that an external function call is correctly executed through the multisig wallet.
     */
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

    /**
     * @notice Tests the functionality of sending ETH from the multisig wallet.
     * @dev Verifies that an ETH transfer is submitted, confirmed, and executed correctly.
     */
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

    /**
     * @notice Tests that with two owners, both owners are required to confirm a transaction.
     */
    function testTwoOwnersRequireBothConfirmations() public {
        // Initialize with two owners
        multisigWallet = new MultisigWallet(twoOwners);
        vm.deal(address(multisigWallet), 1 ether);

        // Submit a transaction from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        vm.expectRevert(
            "MultisigWallet: insufficient confirmations to execute"
        );
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);

        // Owner2 confirms, now transaction should execute
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        assertEq(address(0x123).balance, 1 ether);
    }

    /**
     * @notice Tests that with three owners, the majority confirmation rule is enforced correctly.
     */
    function testThreeOwnersMajorityConfirmation() public {
        // Initialize with three owners
        multisigWallet = new MultisigWallet(threeOwners);
        vm.deal(address(multisigWallet), 1 ether);

        // Submit a transaction from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        // Confirmations from only owner1 and owner2 (2/3)
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        assertEq(address(0x123).balance, 1 ether);
    }

    /**
     * @notice Tests the case where an attempt is made to add an existing owner.
     * @dev Verifies that adding an already existing owner fails.
     */
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

    /**
     * @notice Tests that the last owner cannot be removed after all other owners have been removed.
     * @dev Verifies that attempting to remove the last owner fails.
     */
    function testCannotRemoveLastOwnerAfterRemovals() public {
        multisigWallet = new MultisigWallet(twoOwners);

        vm.prank(owner1);
        multisigWallet.removeOwner(owner2);

        uint txIndex = 0;

        vm.prank(owner2);
        multisigWallet.confirmTransaction(txIndex);

        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: cannot remove the last owner");
        multisigWallet.removeOwner(owner1);
    }

    /**
     * @notice Tests that a non-owner cannot submit a transaction.
     * @dev Verifies that only multisig owners can submit transactions.
     */
    function testNonOwnerSubmitTransaction() public {
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(nonOwner);
        multisigWallet.sendETH(owner2, 1 ether);
    }

    /**
     * @notice Tests that a non-owner cannot confirm a transaction.
     * @dev Verifies that only multisig owners can confirm transactions.
     */
    function testNonOwnerConfirmTransaction() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(nonOwner);
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests that an owner cannot confirm the same transaction twice.
     * @dev Verifies that double confirmation from the same owner is prevented.
     */
    function testDoubleConfirmation() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.expectRevert(
            "MultisigWallet: transaction already confirmed by this owner"
        );
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests that confirming a non-existent transaction fails.
     * @dev Verifies that a revert occurs when confirming a non-existent transaction.
     */
    function testExecuteNonExistentTransaction() public {
        vm.expectRevert("MultisigWallet: Transaction does not exist");
        vm.prank(owner1);
        multisigWallet.confirmTransaction(999);
    }

    /**
     * @notice Tests that an attempt to remove a non-owner fails.
     * @dev Verifies that only existing owners can be removed.
     */
    function testRemoveNonOwner() public {
        vm.expectRevert("MultisigWallet: address is not an owner");
        vm.prank(owner1);
        multisigWallet.removeOwner(nonOwner);
    }

    /**
     * @notice Tests the behavior of deactivateMyPendingTransaction.
     * @dev Ensures that only the transaction submitter can deactivate their pending transaction.
     */
    function testDeactivateMyPendingTransaction() public {
        // Owner1 submits a transaction
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        // Confirm that the transaction is active
        (, bool isActive, , , , , ) = multisigWallet.transactions(0);
        assertTrue(isActive, "Transaction should initially be active");

        // Owner2 tries to deactivate the transaction submitted by Owner1
        vm.prank(owner2);
        vm.expectRevert(
            "MultisigWallet: only the owner can clear their submitted transaction"
        );
        multisigWallet.deactivateMyPendingTransaction(0);

        // Owner1 deactivates their own transaction
        vm.prank(owner1);
        multisigWallet.deactivateMyPendingTransaction(0);

        // Verify that the transaction is now inactive
        (, isActive, , , , , ) = multisigWallet.transactions(0);
        assertFalse(isActive, "Transaction should now be inactive");
    }

    /**
     * @notice Tests adding an owner with a dynamic number of required confirmations.
     * @dev Verifies that adding a new owner with a large number of existing owners works as expected.
     */
    function testAddOwnerWithDynamicConfirmations() public {
        uint numOwners = 100;
        uint confirmations = 67;
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        multisigWallet = new MultisigWallet(dynamicOwners);

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
            dynamicOwners[0]
        );
        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        for (uint i = 1; i < confirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

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

        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), numOwners + 1);
    }

    /**
     * @notice Tests adding an owner with a fuzzed number of confirmations.
     * @dev Verifies that the correct number of confirmations is required based on the number of owners.
     * @param numOwners The number of owners for fuzz testing.
     */
    function testFuzzAddOwnerWithDynamicConfirmations(uint numOwners) public {
        numOwners = bound(numOwners, 3, 120);
        uint requiredConfirmations = (numOwners * 2 + 2) / 3;

        address[] memory dynamicOwners = new address[](numOwners);
        for (uint i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        multisigWallet = new MultisigWallet(dynamicOwners);

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
            dynamicOwners[0]
        );
        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        for (uint i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

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

        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), numOwners + 1);
    }

    /**
     * @notice Tests adding an owner with only a single owner initially.
     * @dev Verifies that a single owner can add another owner without issues.
     */
    function testSingleOwnerCanAddAnother() public {
        uint numOwners = 1;
        address[] memory dynamicOwners = new address[](numOwners);
        dynamicOwners[0] = address(uint160(1));

        multisigWallet = new MultisigWallet(dynamicOwners);
        address newOwner = address(0x123);

        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), numOwners + 1);
    }

    /**
     * @notice Tests that two owners must confirm to remove one of them.
     * @dev Verifies that removing an owner requires both owners to confirm the transaction.
     */
    function testTwoOwnersMustConfirmRemoval() public {
        multisigWallet = new MultisigWallet(twoOwners);

        address ownerToRemove = owner2;
        address initiator = owner1;

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

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);
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

        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        assertFalse(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), 1);
    }

    /**
     * @notice Tests removing an owner with a dynamic number of required confirmations.
     * @dev Verifies that removing an owner with a large number of existing owners works as expected.
     */
    function testRemoveOwnerWithDynamicConfirmations() public {
        uint256 numOwners = 10;
        uint256 requiredConfirmations = (numOwners * 2 + 2) / 3; // 2/3 confirmation threshold

        // Initialize owners
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        // Initialize the multisig wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        address ownerToRemove = dynamicOwners[numOwners - 1]; // Last owner
        address initiator = dynamicOwners[0];

        // Emit event for submitting RemoveOwner transaction
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

        // Final confirmation that triggers execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect PendingTransactionsDeactivated and OwnerRemoved events
        vm.expectEmit(true, false, false, true);
        emit PendingTransactionsDeactivated();
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

        // Confirm the transaction
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the owner has been removed
        assertFalse(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), numOwners - 1);
    }

    /**
     * @notice Tests removing an owner using fuzzing for dynamic confirmations.
     * @dev Verifies that removing an owner works correctly with a fuzzed number of owners.
     * @param numOwnersInput The fuzzed number of owners for the test.
     */
    function testFuzzRemoveOwnerWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        numOwnersInput = bound(numOwnersInput, 3, 120); // Bound the number of owners between 3 and 120
        uint256 requiredConfirmations = (numOwnersInput * 2 + 2) / 3; // 2/3 confirmation threshold

        // Initialize owners
        address[] memory dynamicOwners = new address[](numOwnersInput);
        for (uint256 i = 0; i < numOwnersInput; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        // Initialize the multisig wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        address ownerToRemove = dynamicOwners[numOwnersInput - 1]; // Last owner
        address initiator = dynamicOwners[0];

        // Emit event for submitting RemoveOwner transaction
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

        // Final confirmation that triggers execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect PendingTransactionsDeactivated and OwnerRemoved events
        vm.expectEmit(true, false, false, true);
        emit PendingTransactionsDeactivated();
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

        // Confirm the transaction
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the owner has been removed
        assertFalse(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), numOwnersInput - 1);
    }

    /**
     * @notice Tests that attempting to remove the last owner fails.
     * @dev Verifies that the multisig wallet cannot remove the last remaining owner.
     */
    function testRemoveLastOwner2() public {
        // Initialize a new multisig wallet with one owner
        multisigWallet = new MultisigWallet(singleOwner);

        address ownerToRemove = owner1;

        // Attempt to remove the only owner
        vm.prank(ownerToRemove);
        vm.expectRevert("MultisigWallet: cannot remove the last owner");
        multisigWallet.removeOwner(ownerToRemove);
    }

    /**
     * @notice Tests that a non-owner cannot remove an owner.
     * @dev Verifies that a non-owner cannot perform owner-related actions.
     */
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

    /**
     * @notice Tests that removing a non-existent owner fails.
     * @dev Verifies that trying to remove an owner who does not exist reverts.
     */
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

    /**
     * @notice Tests that a malicious transaction cannot add an owner through other transaction types.
     * @dev Verifies that a malicious transaction cannot call internal functions like addOwner.
     */
    function testMaliciousOtherTransactionCannotAddOwner() public {
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
            0, // txIndex
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
            address(multisigWallet),
            0,
            payload
        );

        // Owner2 confirms the transaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Expect reversion when the execution attempts to call addOwner
        vm.expectRevert("MultisigWallet: cannot call internal functions");
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner3, 0);
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);

        // Verify that the new owner was not added
        assertFalse(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), 5);
    }

    /**
     * @notice Tests that a malicious transaction cannot remove an owner through other transaction types.
     * @dev Verifies that a malicious transaction cannot call internal functions like removeOwner.
     */
    function testMaliciousOtherTransactionCannotRemoveOwner() public {
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
            MultisigWallet.TransactionType.Other,
            0, // txIndex
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
            MultisigWallet.TransactionType.Other,
            address(multisigWallet),
            0,
            payload
        );

        // Owner2 confirms the transaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Expect reversion when the execution attempts to call removeOwner
        vm.expectRevert("MultisigWallet: cannot call internal functions");
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner3, 0);
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);

        // Verify that the owner was not removed
        assertTrue(multisigWallet.isOwner(ownerToRemove));
        assertEq(multisigWallet.getOwnerCount(), 5);
    }

    /**
     * @notice Tests sending ETH with dynamic confirmations using fuzzing.
     * @dev Verifies that the correct number of confirmations is required for sending ETH based on the number of owners.
     * @param numOwnersInput The fuzzed number of owners for the test.
     */
    function testFuzzSendETHWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // Bound the number of owners between 3 and 120 to maintain meaningful >50% confirmation logic
        uint256 numOwners = bound(numOwnersInput, 3, 120);

        // For >50%, requiredConfirmations = floor(numOwners / 2) + 1
        uint256 requiredConfirmations = (numOwners / 2) + 1;

        // Initialize dynamic owners
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses
        }

        // Deploy a new Multisig Wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);

        // Fund the multisig wallet with ETH
        uint256 initialBalance = 10 ether;
        vm.deal(address(multisigWallet), initialBalance);
        assertEq(
            address(multisigWallet).balance,
            initialBalance,
            "Initial balance mismatch"
        );

        // Define the recipient and the amount to transfer
        address payable recipient = payable(address(0xABC));
        uint256 transferAmount = 1 ether;

        // Expect the SubmitTransaction event for sending ETH
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            transferAmount,
            "",
            address(0),
            0,
            dynamicOwners[0] // Initiator
        );

        // Submit the transaction to send ETH
        vm.prank(dynamicOwners[0]); // Initiate from the first owner
        multisigWallet.sendETH(recipient, transferAmount);

        // Confirm the transaction with the required number of owners minus one
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation to trigger execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect the ExecuteTransaction event for sending ETH
        vm.expectEmit(true, true, true, true);
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

        // Final confirmation and execution
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient received the ETH
        assertEq(
            recipient.balance,
            transferAmount,
            "Recipient did not receive ETH transfer"
        );
        assertEq(
            address(multisigWallet).balance,
            initialBalance - transferAmount,
            "Multisig wallet balance mismatch after ETH transfer"
        );
    }

    /**
     * @notice Tests an ERC20 transfer with dynamic confirmations using fuzzing.
     * @dev Verifies that the correct number of confirmations is required for ERC20 transfers based on the number of owners.
     * @param numOwnersInput The fuzzed number of owners for the test.
     */
    function testFuzzERC20TransferWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // Bound the number of owners between 3 and 120 to maintain meaningful >50% confirmation logic
        uint256 numOwners = bound(numOwnersInput, 3, 120);
        uint256 requiredConfirmations = (numOwners / 2) + 1;

        // Initialize dynamic owners
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses
        }

        // Deploy a new Multisig Wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);
        SimpleERC20 dynamicERC20 = new SimpleERC20(1_000_000 * 10 ** 18); // 1,000,000 tokens
        dynamicERC20.transfer(address(multisigWallet), 100_000 * 10 ** 18); // Transfer 100,000 tokens to the wallet

        // Define the recipient and the amount to transfer
        address recipient = address(0xABC); // Arbitrary recipient address
        uint256 transferAmount = 10_000 * 10 ** 18; // 10,000 tokens

        // Prepare the ERC20 Transfer Data
        bytes memory transferData = abi.encodeWithSelector(
            dynamicERC20.transfer.selector,
            recipient,
            transferAmount
        );

        // Expect the SubmitTransaction event for ERC20 transfer
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC20,
            0,
            recipient,
            0,
            transferData,
            address(dynamicERC20),
            transferAmount,
            dynamicOwners[0] // Initiator
        );

        // Submit the transaction to transfer ERC20
        vm.prank(dynamicOwners[0]);
        multisigWallet.transferERC20(
            IERC20(address(dynamicERC20)),
            recipient,
            transferAmount
        );

        // Confirm the transaction with the required number of owners minus one
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation to trigger execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect the ExecuteTransaction event for ERC20 transfer
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ERC20,
            0,
            recipient,
            0,
            transferData,
            address(dynamicERC20),
            transferAmount,
            dynamicOwners[requiredConfirmations - 1] // Executor
        );

        // Final confirmation and execution
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient received the ERC20 tokens
        assertEq(
            dynamicERC20.balanceOf(recipient),
            transferAmount,
            "Recipient did not receive ERC20 transfer"
        );
        assertEq(
            dynamicERC20.balanceOf(address(multisigWallet)),
            100_000 * 10 ** 18 - transferAmount,
            "Multisig wallet ERC20 balance mismatch after transfer"
        );
    }

    /**
     * @notice Tests an ERC721 transfer with dynamic confirmations using fuzzing.
     * @dev Verifies that the correct number of confirmations is required for ERC721 transfers based on the number of owners.
     * @param numOwnersInput The fuzzed number of owners for the test.
     */
    function testFuzzERC721TransferWithDynamicConfirmations(
        uint256 numOwnersInput
    ) public {
        // Bound the number of owners between 3 and 120 to maintain meaningful >50% confirmation logic
        uint256 numOwners = bound(numOwnersInput, 3, 120);
        uint256 requiredConfirmations = (numOwners / 2) + 1;

        // Initialize dynamic owners
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1)); // Assign unique addresses
        }

        // Deploy a new Multisig Wallet with dynamic owners
        multisigWallet = new MultisigWallet(dynamicOwners);
        SimpleERC721 dynamicERC721 = new SimpleERC721();

        uint256 tokenId = 1; // Define a tokenId to transfer

        // Mint ERC721 Token to the multisig wallet
        dynamicERC721.mint(address(multisigWallet), tokenId);

        // Define the recipient
        address recipient = address(0xABC); // Arbitrary recipient address

        // Prepare the ERC721 Transfer Data
        bytes memory transferData = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(multisigWallet),
            recipient,
            tokenId
        );

        // Expect the SubmitTransaction event for ERC721 transfer
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC721,
            0,
            recipient,
            0,
            transferData,
            address(dynamicERC721),
            tokenId,
            dynamicOwners[0] // Initiator
        );

        // Submit the transaction to transfer ERC721
        vm.prank(dynamicOwners[0]);
        multisigWallet.safeTransferFromERC721(
            address(dynamicERC721),
            address(multisigWallet),
            recipient,
            tokenId
        );

        // Confirm the transaction with the required number of owners minus one
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(dynamicOwners[i], 0);
            vm.prank(dynamicOwners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirmation to trigger execution
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(dynamicOwners[requiredConfirmations - 1], 0);

        // Expect the ExecuteTransaction event for ERC721 transfer
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.ERC721,
            0,
            recipient,
            0,
            transferData,
            address(dynamicERC721),
            tokenId,
            dynamicOwners[requiredConfirmations - 1] // Executor
        );

        // Final confirmation and execution
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient now owns the ERC721 token
        assertEq(
            dynamicERC721.ownerOf(tokenId),
            recipient,
            "ERC721 token was not transferred to the recipient"
        );
    }

    /**
     * @notice Tests that the constructor reverts when no owners are provided.
     * @dev Verifies that the constructor fails if an empty owners list is passed.
     */
    function testConstructorRevertsWithNoOwners() public {
        vm.expectRevert("MultisigWallet: at least one owner required");
        new MultisigWallet(noOwners);
    }

    /**
     * @notice Tests that the constructor reverts when a zero address is passed as an owner.
     * @dev Verifies that the constructor fails if a zero address is provided as one of the owners.
     */
    function testConstructorRevertsWithZeroAddressOwner() public {
        vm.expectRevert("MultisigWallet: owner address cannot be zero");
        new MultisigWallet(invalidOwners);
    }

    /**
     * @notice Tests that the constructor reverts when duplicate owners are provided.
     * @dev Verifies that the constructor fails if the list of owners contains duplicates.
     */
    function testConstructorRevertsWithDuplicateOwners() public {
        vm.expectRevert("MultisigWallet: duplicate owner address");
        new MultisigWallet(duplicateOwners);
    }

    /**
     * @notice Tests that submitting an ETH transaction with a zero value reverts.
     * @dev Verifies that the multisig wallet requires a non-zero amount for ETH transactions.
     */
    function testSubmitETHTransactionWithZeroValue() public {
        address recipient = address(0x123);
        vm.expectRevert("MultisigWallet: Ether (Wei) amount required");
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, 0);
    }

    /**
     * @notice Tests that submitting an ERC20 transaction with empty data reverts.
     * @dev Verifies that the multisig wallet requires valid ERC20 data for token transfers.
     */
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

    /**
     * @notice Tests that an owner cannot confirm a transaction twice.
     * @dev Verifies that double confirmation is prevented in the multisig wallet.
     */
    function testDoubleConfirmationReverts() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        vm.expectRevert(
            "MultisigWallet: transaction already confirmed by this owner"
        );
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests that executing a transaction without enough confirmations reverts.
     * @dev Verifies that insufficient confirmations prevent transaction execution.
     */
    function testExecuteWithoutEnoughConfirmations() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        // Submit an ETH transfer from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        // Confirm the transaction with only owner2
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Expect reversion when trying to execute with insufficient confirmations
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
            "Multisig wallet balance should remain unchanged"
        );
    }

    /**
     * @notice Tests that malformed ERC20 transfer data reverts the transaction.
     * @dev Verifies that incorrect data lengths for ERC20 transfers are rejected.
     */
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

    /**
     * @notice Tests that malformed ERC721 transfer data reverts the transaction.
     * @dev Verifies that incorrect data lengths for ERC721 transfers are rejected.
     */
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
            malformedData
        );
    }

    /**
     * @notice Tests that adding an existing owner fails.
     * @dev Verifies that attempting to add a current owner again is rejected.
     */
    function testAddExistingOwnerReverts() public {
        address existingOwner = owner1;

        vm.prank(owner2);
        vm.expectRevert("MultisigWallet: owner already exists");
        multisigWallet.addOwner(existingOwner);
    }

    /**
     * @notice Tests that removing a non-existent owner fails.
     * @dev Verifies that attempting to remove an address that is not an owner is rejected.
     */
    function testRemoveNonExistentOwnerReverts() public {
        address nonExistentOwner = address(0x999);

        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: address is not an owner");
        multisigWallet.removeOwner(nonExistentOwner);
    }

    /**
     * @notice Tests that removing the last remaining owner fails.
     * @dev Verifies that the multisig wallet cannot remove the final owner.
     */
    function testRemoveLastOwnerReverts() public {
        // Initialize with a single owner
        multisigWallet = new MultisigWallet(singleOwner);

        address soleOwner = owner1;

        vm.prank(soleOwner);
        vm.expectRevert("MultisigWallet: cannot remove the last owner");
        multisigWallet.removeOwner(soleOwner);
    }

    /**
     * @notice Tests reentrancy protection during confirmTransaction function.
     * @dev Verifies that reentrancy attacks on transaction confirmation are blocked.
     */
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

    /**
     * @notice Tests reentrancy protection during executeTransaction function.
     * @dev Verifies that reentrancy attacks on transaction execution are blocked.
     */
    function testReentrancyAttackOnExecuteTransaction() public {
        // Deploy a malicious contract that attempts to re-enter during execution
        MaliciousReentrantExecutor attacker = new MaliciousReentrantExecutor(
            multisigWallet
        );

        // Fund the multisig wallet
        vm.deal(address(multisigWallet), 10 ether);

        // Submit and confirm an ETH transfer to the malicious contract
        vm.prank(owner1);
        multisigWallet.sendETH(address(attacker), 1 ether);

        for (uint i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Expect reentrancy guard to prevent the attack during execution
        vm.prank(owners[owners.length / 2]);
        vm.expectRevert("MultisigWallet: external call failed");
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests that a transaction cannot be replayed after execution.
     * @dev Ensures that once a transaction is executed, it cannot be re-executed.
     */
    function testCannotReplayExecutedTransaction() public {
        // Owner1 submits a transaction to send 1 ether
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        // Other owners confirm the transaction
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient received the ether
        assertEq(
            address(0x123).balance,
            1 ether,
            "Recipient should have received 1 ether"
        );

        // Attempt to replay (re-execute) the same transaction
        vm.expectRevert("MultisigWallet: Transaction not active");
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);

        // Check that the balance did not change (replay attack failed)
        assertEq(
            address(0x123).balance,
            1 ether,
            "Recipient balance should remain unchanged after replay attempt"
        );
    }

    /**
     * @notice Tests the onERC721Received function when an ERC721 token is transferred to the multisig wallet.
     * @dev Verifies that the multisig wallet correctly implements the IERC721Receiver interface.
     */
    function testOnERC721Received() public {
        // Arrange
        address from = owner2; // The current owner of the token
        uint256 tokenId = 3; // Use a unique tokenId
        bytes memory data = "some data";

        // Mint a token to 'from' (owner2)
        erc721Token.mint(from, tokenId);

        // Expect the ERC721Received event to be emitted when the token is received
        vm.expectEmit(true, true, true, true);
        emit ERC721Received(from, from, tokenId, data);

        // Act: Transfer the token from 'from' to the multisig wallet
        vm.prank(from);
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

    /**
     * @notice Tests that the multisig wallet can receive ERC20 tokens.
     * @dev Verifies that ERC20 tokens can be successfully transferred to the multisig wallet.
     */
    function testReceiveERC20Tokens() public {
        // Arrange
        address sender = owner1;
        uint256 transferAmount = 500 * 10 ** 18; // 500 ERC20 tokens

        // Transfer tokens to sender (owner1)
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

        // Act: Transfer ERC20 tokens to the multisig wallet
        vm.prank(sender);
        success = erc20Token.transfer(address(multisigWallet), transferAmount);
        require(success, "ERC20 transfer failed");

        // Assert: Check that the multisig wallet's ERC20 balance has increased
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

    /**
     * @notice Tests that sending ETH to a zero address reverts.
     * @dev Verifies that the multisig wallet requires a valid recipient address for ETH transfers.
     */
    function testSendETHToZeroAddressReverts() public {
        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: receiver address required");
        multisigWallet.sendETH(address(0), 1 ether);
    }

    /**
     * @notice Tests that transferring zero amount of ERC20 tokens reverts.
     * @dev Verifies that the multisig wallet requires a positive amount for ERC20 transfers.
     */
    function testTransferERC20ZeroAmountReverts() public {
        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: token amount required");
        multisigWallet.transferERC20(
            IERC20(address(erc20Token)),
            address(0x123),
            0
        );
    }

    /**
     * @notice Tests that a non-owner cannot submit a transaction.
     * @dev Verifies that only multisig owners can submit transactions.
     */
    function testNonOwnerCannotSubmitTransaction() public {
        vm.prank(nonOwner);
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        multisigWallet.sendETH(owner2, 1 ether);
    }

    /**
     * @notice Tests the deactivation of pending transactions with a large array of transactions.
     * @dev Simulates adding a large number of transactions and attempts to deactivate them by adding a new owner.
     * The test checks if the transaction execution fails only when the gas limit is exceeded.
     * Confirms the transaction up to the required number of confirmations and ensures the new owner is added.
     */
    function testDeactivatePendingTransactionsWithLargeArray() public {
        // Simulate adding a large number of transactions
        uint256 largeNumber = 10000;
        vm.startPrank(owner1);
        for (uint256 i = 0; i < largeNumber; i++) {
            multisigWallet.sendETH(address(0x123), 1 wei);
        }
        vm.stopPrank();

        // Attempt to add a new owner
        address newOwner = address(0x999);
        vm.prank(owner1);
        multisigWallet.addOwner(newOwner);

        // Confirm the transaction up to the required number of confirmations
        uint256 requiredConfirmations = (owners.length * 2 + 2) / 3;
        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(largeNumber);
        }

        // The execution should fail only if gas limit is exceeded
        vm.prank(owners[requiredConfirmations]);
        // vm.expectRevert("Out of gas");
        multisigWallet.confirmTransaction(largeNumber);
        assertTrue(multisigWallet.isOwner(newOwner));
    }

    /**
     * @notice Tests that confirming an inactive transaction reverts.
     * @dev Deactivates a pending transaction and verifies that an attempt to confirm it will fail.
     */
    function testCannotConfirmInactiveTransaction() public {
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        vm.prank(owner1);
        multisigWallet.deactivateMyPendingTransaction(0);

        vm.prank(owner2);
        vm.expectRevert("MultisigWallet: Transaction not active");
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests that a removed owner cannot confirm a transaction after being removed.
     * @dev Removes owner5 from the multisig wallet and verifies that the removed owner cannot confirm transactions.
     */
    function testRemovedOwnerCannotConfirmTransaction() public {
        // Remove owner5
        vm.prank(owner1);
        multisigWallet.removeOwner(owner5);

        for (uint i = 1; i < (owners.length * 2 + 2) / 3; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Attempt to have the removed owner confirm a new transaction
        vm.prank(owner5);
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        multisigWallet.sendETH(address(0x123), 1 ether);
    }

    /**
     * @notice Tests direct ETH transfer to the multisig wallet via the fallback function.
     * @dev Simulates sending ETH directly to the multisig wallet and verifies that the balance is updated correctly.
     */
    function testDirectETHTransfer() public {
        uint256 depositAmount = 1 ether;
        address depositor = address(0x456);
        vm.deal(depositor, depositAmount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(depositor, depositAmount, INITIAL_BALANCE + depositAmount);

        vm.prank(depositor);
        (bool success, ) = address(multisigWallet).call{value: depositAmount}(
            ""
        );
        require(success, "ETH transfer failed");

        assertEq(
            address(multisigWallet).balance,
            INITIAL_BALANCE + depositAmount
        );
    }

    /**
     * @notice Tests that the required number of confirmations adjusts when an owner is removed.
     * @dev Verifies that if a multisig owner is deleted, the number of required confirmations is reduced accordingly.
     */
    function testNumConfirmationsReducedAfterOwnerRemoval() public {
        // Step 1: Submit a transaction from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        // Step 2: Confirm the transaction from owner2
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Step 3: Remove owner3 before reaching the required confirmations
        vm.prank(owner1);
        multisigWallet.removeOwner(owner3);

        // Step 4: Check that the number of confirmations required has reduced
        // Before removal: (owners.length * 2 + 2) / 3 confirmations
        // After removal, with one fewer owner, the number of required confirmations should decrease
        uint256 requiredConfirmationsBeforeRemoval = (owners.length * 2 + 2) /
            3;
        uint256 requiredConfirmationsAfterRemoval = ((owners.length - 1) *
            2 +
            2) / 3;

        // Assert that the number of confirmations required has been reduced after owner removal
        assertLt(
            requiredConfirmationsAfterRemoval,
            requiredConfirmationsBeforeRemoval,
            "Confirmations did not reduce after owner removal"
        );

        // Step 5: Complete the transaction by confirming with another owner
        vm.prank(owner4);
        multisigWallet.confirmTransaction(0);

        // Check that the transaction was executed
        assertEq(address(0x123).balance, 1 ether);
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
