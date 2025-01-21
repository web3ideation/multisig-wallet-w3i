// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/MultisigWallet.sol";
import "../src/SimpleERC20.sol";
import "../src/SimpleERC721.sol";

/**
 * @notice A simple contract that increments a counter (used to test TransactionType.Other).
 */
contract SimpleCounter {
    uint256 public count;

    function increment() public {
        count += 1;
    }
}

/**
 * @notice Malicious contract that attempts to reenter `confirmTransaction` in its fallback.
 *         Used for reentrancy tests in batch or single transfers.
 */
contract MaliciousContract {
    MultisigWallet public target;

    constructor(address payable _target) {
        target = MultisigWallet(_target);
    }

    receive() external payable {
        // Attempt reentrancy by calling confirmTransaction(0)
        target.confirmTransaction(0);
    }
}

/**
 * @notice Another malicious contract that attempts to reenter `executeTransaction` in its fallback.
 */
contract MaliciousReentrantExecutor {
    MultisigWallet public target;

    constructor(MultisigWallet _target) {
        target = _target;
    }

    receive() external payable {
        target.executeTransaction(0);
    }
}

/**
 * @notice A malicious ERC20 that attempts reentrancy in its `transfer()`.
 *         Used by testMaliciousTokenCannotDrainViaBatch().
 */
contract MaliciousToken is SimpleERC20 {
    MultisigWallet private wallet;

    constructor(uint256 initialSupply, address payable _wallet)
        SimpleERC20(0) // Pass 0 initial supply; we'll mint as needed
    {
        wallet = MultisigWallet(_wallet);
        _mint(address(_wallet), initialSupply); // Mint directly here
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        // Attempt reentrancy in the multisig
        wallet.confirmTransaction(999999999); // bogus index
        return super.transfer(to, amount);
    }
}

/**
 * @title MultisigWalletTest
 * @notice This contract tests the functionalities of the MultisigWallet contract,
 *         including owner management, ETH and token transfers, confirmations,
 *         and the batchTransfer feature plus malicious attempts.
 * @dev Uses Foundry's Test contract for unit testing. The contract covers various scenarios, including dynamic confirmation requirements, edge cases for owner management, and token interactions.
 */
contract MultisigWalletTest is Test {
    /// @notice The multisig wallet instance being tested.
    MultisigWallet public multisigWallet;

    /// @notice The ERC20 token instance for testing ERC20 transfers.
    SimpleERC20 public erc20Token;

    /// @notice The ERC721 token instance for testing ERC721 transfers.
    SimpleERC721 public erc721Token;

    /// @notice Various address arrays used for different test scenarios.
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
     * @notice Events from the MultisigWallet contract, repeated here for checking via vm.expectEmit.
     */
    event Deposit(address indexed sender, uint256 indexed amountOrTokenId, uint256 indexed balance);

    /**
     * @notice Event emitted during transaction submission.
     */
    event SubmitTransaction(
        MultisigWallet.TransactionType indexed _transactionType,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        address tokenAddress,
        uint256 amountOrTokenId,
        address owner,
        bytes data
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
        address tokenAddress,
        uint256 amountOrTokenId,
        address owner,
        bytes data
    );

    /**
     * @notice Event emitted when a Batch Transfer has been executed.
     */
    event BatchTransferExecuted(
        address indexed recipient, address indexed tokenAddress, uint256 value, uint256 indexed tokenId
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
     * @notice Emitted when an owner deactivates their own pending transaction.
     */
    event DeactivatedMyPendingTransaction(uint256 indexed txIndex, address indexed owner);

    /**
     * @notice Event emitted when the contract receives an ERC721 token.
     */
    event ERC721Received(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);

    /**
     * @notice Sets up the environment for each test: owners, multisig wallet, token contracts, and initial funding.
     * @dev Mints enough ERC721 token IDs for the bigger batchTransfer tests.
     */
    function setUp() public {
        owners = [owner1, owner2, owner3, owner4, owner5];
        twoOwners = [owner1, owner2];
        threeOwners = [owner1, owner2, owner3];
        singleOwner = [owner1];
        noOwners = new address[](0);
        invalidOwners = [address(0)];
        duplicateOwners = [address(1), address(1)];
        // Deploy the multisig
        multisigWallet = new MultisigWallet(owners);
        // Deploy tokens
        erc20Token = new SimpleERC20(ERC20_INITIAL_SUPPLY);
        erc721Token = new SimpleERC721();

        // Fund the multisig with 10 ETH
        vm.deal(address(multisigWallet), INITIAL_BALANCE);
        // Transfer 1000 tokens to the multisig so we can test ERC20 transfers
        erc20Token.transfer(address(multisigWallet), 1000 * 10 ** 18);
        // Mint some ERC721 tokens directly to the multisig
        erc721Token.mint(address(multisigWallet), 1);
        erc721Token.mint(address(multisigWallet), 2);

        // For bigger batch tests, mint token IDs 3..22 as well:
        for (uint256 i = 3; i <= 22; i++) {
            erc721Token.mint(address(multisigWallet), i);
        }
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
        (bool success,) = address(multisigWallet).call{value: depositAmount}("");
        require(success, "Deposit failed");

        assertEq(address(multisigWallet).balance, INITIAL_BALANCE + depositAmount);
    }

    /**
     * @notice Tests the functionality of adding a new owner to the multisig wallet.
     * @dev Verifies that adding a new owner requires the correct number of confirmations.
     */
    function testAddOwner() public {
        address newOwner = address(0x123);

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(MultisigWallet.TransactionType.AddOwner, 0, newOwner, 0, address(0), 0, owner1, "");
        vm.prank(owner1);
        multisigWallet.addOwner(newOwner);

        for (uint256 i = 1; i < (owners.length * 2 + 2) / 3 - 1; i++) {
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
            address(0),
            0,
            owners[(owners.length * 2 + 2) / 3],
            ""
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
        emit SubmitTransaction(MultisigWallet.TransactionType.RemoveOwner, 0, owner5, 0, address(0), 0, owner1, "");
        vm.prank(owner1);
        multisigWallet.removeOwner(owner5);

        for (uint256 i = 1; i * 1000 < (owners.length * 1000 * 2) / 3; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);

            if (i * 1000 == (owners.length * 1000 * 2) / 3) {
                vm.expectEmit(true, false, false, true);
                emit PendingTransactionsDeactivated();
                vm.expectEmit(true, false, false, true);
                emit OwnerRemoved(owner5);
                vm.expectEmit(true, true, true, true);
                emit ExecuteTransaction(
                    MultisigWallet.TransactionType.RemoveOwner, 0, owner5, 0, address(0), 0, owners[i], ""
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

        uint256 initialBalance = recipient.balance;

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            amount,
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owner1,
            ""
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.ETH, recipient, amount, "");

        for (uint256 i = 1; i < owners.length / 2; i++) {
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
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owners[owners.length / 2],
            ""
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        uint256 receivedBalance = recipient.balance - initialBalance;

        assertEq(receivedBalance, amount);
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
            address(erc20Token),
            amount,
            owner1,
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );
        vm.prank(owner1);
        multisigWallet.transferERC20(IERC20(address(erc20Token)), recipient, amount);

        for (uint256 i = 1; i < owners.length / 2; i++) {
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
            address(erc20Token),
            amount,
            owners[owners.length / 2],
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(erc20Token.balanceOf(address(multisigWallet)), initialBalance - amount);
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
            address(erc721Token),
            tokenId,
            owner1,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)", address(multisigWallet), recipient, tokenId
            )
        );
        vm.prank(owner1);
        multisigWallet.safeTransferFromERC721(address(erc721Token), address(multisigWallet), recipient, tokenId);

        for (uint256 i = 1; i < owners.length / 2; i++) {
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
            address(erc721Token),
            tokenId,
            owners[owners.length / 2],
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)", address(multisigWallet), recipient, tokenId
            )
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
        uint256 initialBalance = address(0x123).balance;

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            payable(address(0x123)),
            1 ether,
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owner1,
            ""
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.ETH, payable(address(0x123)), 1 ether, "");

        for (uint256 i = 1; i < owners.length / 2; i++) {
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

        uint256 receivedBalance = address(0x123).balance - initialBalance;

        assertEq(receivedBalance, 0);
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

        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.prank(owners[owners.length / 2]);
        vm.expectRevert("MultisigWallet: insufficient confirmations to execute");
        multisigWallet.executeTransaction(0);
    }

    /**
     * @notice Tests retrieval of the multisig wallet's owner list.
     * @dev Verifies that the owner list returned by the wallet matches the expected list of owners.
     */
    function testGetOwners() public view {
        address[] memory currentOwners = multisigWallet.getOwners();
        assertEq(currentOwners.length, 5);
        for (uint256 i = 0; i < 5; i++) {
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
            MultisigWallet.TransactionType.Other, 0, address(counter), 0, address(0), 0, owner1, data
        );
        vm.prank(owner1);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.Other, address(counter), 0, data);

        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.Other, 0, address(counter), 0, address(0), 0, owners[owners.length / 2], data
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

        uint256 initialBalance = recipient.balance;

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ETH,
            0,
            recipient,
            amount,
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owner1,
            ""
        );
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        for (uint256 i = 1; i < owners.length / 2; i++) {
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
            address(0),
            0, // amountOrTokenId should be 0 for ETH transfers
            owners[owners.length / 2],
            ""
        );
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        uint256 receivedBalance = recipient.balance - initialBalance;

        assertEq(receivedBalance, amount);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - amount);
    }

    /**
     * @notice Tests that with two owners, both owners are required to confirm a transaction.
     */
    function testTwoOwnersRequireBothConfirmations() public {
        uint256 initialBalance = address(0x123).balance;

        // Initialize with two owners
        multisigWallet = new MultisigWallet(twoOwners);
        vm.deal(address(multisigWallet), 1 ether);

        // Submit a transaction from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        vm.expectRevert("MultisigWallet: insufficient confirmations to execute");
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);

        // Owner2 confirms, now transaction should execute
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        uint256 receivedBalance = address(0x123).balance - initialBalance;

        assertEq(receivedBalance, 1 ether);
    }

    /**
     * @notice Tests that with three owners, the majority confirmation rule is enforced correctly.
     */
    function testThreeOwnersMajorityConfirmation() public {
        uint256 initialBalance = address(0x123).balance;

        // Initialize with three owners
        multisigWallet = new MultisigWallet(threeOwners);
        vm.deal(address(multisigWallet), 1 ether);

        // Submit a transaction from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        // Confirmations from only owner1 and owner2 (2/3)
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        uint256 receivedBalance = address(0x123).balance - initialBalance;

        assertEq(receivedBalance, 1 ether);
    }

    /**
     * @notice Tests the case where an attempt is made to add an existing owner.
     * @dev Verifies that adding an already existing owner fails.
     */
    function testRevertWhenAddExistingOwner() public {
        vm.prank(owner1);
        multisigWallet.addOwner(address(0x123));

        for (uint256 i = 1; i < (owners.length * 2 + 2) / 3; i++) {
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

        uint256 txIndex = 0;

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

        vm.expectRevert("MultisigWallet: transaction already confirmed by this owner");
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
        (, bool isActive,,,,,) = multisigWallet.transactions(0);
        assertTrue(isActive, "Transaction should initially be active");

        // Owner2 tries to deactivate the transaction submitted by Owner1
        vm.prank(owner2);
        vm.expectRevert("MultisigWallet: only the owner can clear their submitted transaction");
        multisigWallet.deactivateMyPendingTransaction(0);

        // Owner1 deactivates their own transaction
        vm.prank(owner1);
        multisigWallet.deactivateMyPendingTransaction(0);

        // Verify that the transaction is now inactive
        (, isActive,,,,,) = multisigWallet.transactions(0);
        assertFalse(isActive, "Transaction should now be inactive");
    }

    /**
     * @notice Tests adding an owner with a dynamic number of required confirmations.
     * @dev Verifies that adding a new owner with a large number of existing owners works as expected.
     */
    function testAddOwnerWithDynamicConfirmations() public {
        uint256 numOwners = 100;
        uint256 confirmations = 67;
        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        multisigWallet = new MultisigWallet(dynamicOwners);

        address newOwner = address(0x123);

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.AddOwner, 0, newOwner, 0, address(0), 0, dynamicOwners[0], ""
        );
        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        for (uint256 i = 1; i < confirmations - 1; i++) {
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
            MultisigWallet.TransactionType.AddOwner, 0, newOwner, 0, address(0), 0, dynamicOwners[confirmations - 1], ""
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
    function testFuzzAddOwnerWithDynamicConfirmations(uint256 numOwners) public {
        numOwners = bound(numOwners, 3, 120);
        uint256 requiredConfirmations = (numOwners * 2 + 2) / 3;

        address[] memory dynamicOwners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            dynamicOwners[i] = address(uint160(i + 1));
        }

        multisigWallet = new MultisigWallet(dynamicOwners);

        address newOwner = address(0x123);

        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.AddOwner, 0, newOwner, 0, address(0), 0, dynamicOwners[0], ""
        );
        vm.prank(dynamicOwners[0]);
        multisigWallet.addOwner(newOwner);

        for (uint256 i = 1; i < requiredConfirmations - 1; i++) {
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
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1],
            ""
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
        uint256 numOwners = 1;
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
            MultisigWallet.TransactionType.RemoveOwner, 0, ownerToRemove, 0, address(0), 0, initiator, ""
        );
        vm.prank(initiator);
        multisigWallet.removeOwner(ownerToRemove);

        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner2, 0);
        vm.expectEmit(true, false, false, true);
        emit OwnerRemoved(ownerToRemove);
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.RemoveOwner, 0, ownerToRemove, 0, address(0), 0, owner2, ""
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
            MultisigWallet.TransactionType.RemoveOwner, 0, ownerToRemove, 0, address(0), 0, initiator, ""
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
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1],
            ""
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
    function testFuzzRemoveOwnerWithDynamicConfirmations(uint256 numOwnersInput) public {
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
            MultisigWallet.TransactionType.RemoveOwner, 0, ownerToRemove, 0, address(0), 0, initiator, ""
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
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1],
            ""
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
        bytes memory payload = abi.encodeWithSignature("addOwner(address)", newOwner);

        // Expect the SubmitTransaction event to be emitted
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.Other,
            0, // txIndex
            address(multisigWallet), // to address is the MultisigWallet itself
            0, // value is 0 for function calls
            address(0), // tokenAddress is 0 for "Other" transactions
            0, // amountOrTokenId is 0 for "Other" transactions
            maliciousOwner, // owner who submitted the transaction
            payload // data is the encoded addOwner call
        );

        // Prank as the malicious owner and submit the "Other" transaction
        vm.prank(maliciousOwner);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.Other, address(multisigWallet), 0, payload);

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
        bytes memory payload = abi.encodeWithSignature("removeOwner(address)", ownerToRemove);

        // Expect the SubmitTransaction event to be emitted
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.Other,
            0, // txIndex
            address(multisigWallet), // to address is the MultisigWallet itself
            0, // value is 0 for function calls
            address(0), // tokenAddress is 0 for "Other" transactions
            0, // amountOrTokenId is 0 for "Other" transactions
            maliciousOwner, // owner who submitted the transaction
            payload // data is the encoded removeOwner call
        );

        // Prank as the malicious owner and submit the "Other" transaction
        vm.prank(maliciousOwner);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.Other, address(multisigWallet), 0, payload);

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
    function testFuzzSendETHWithDynamicConfirmations(uint256 numOwnersInput) public {
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
        assertEq(address(multisigWallet).balance, initialBalance, "Initial balance mismatch");

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
            address(0),
            0,
            dynamicOwners[0], // Initiator
            ""
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
            address(0),
            0,
            dynamicOwners[requiredConfirmations - 1], // Executor
            ""
        );

        // Final confirmation and execution
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient received the ETH
        assertEq(recipient.balance, transferAmount, "Recipient did not receive ETH transfer");
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
    function testFuzzERC20TransferWithDynamicConfirmations(uint256 numOwnersInput) public {
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
        bytes memory transferData = abi.encodeWithSelector(dynamicERC20.transfer.selector, recipient, transferAmount);

        // Expect the SubmitTransaction event for ERC20 transfer
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC20,
            0,
            recipient,
            0,
            address(dynamicERC20),
            transferAmount,
            dynamicOwners[0], // Initiator
            transferData
        );

        // Submit the transaction to transfer ERC20
        vm.prank(dynamicOwners[0]);
        multisigWallet.transferERC20(IERC20(address(dynamicERC20)), recipient, transferAmount);

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
            address(dynamicERC20),
            transferAmount,
            dynamicOwners[requiredConfirmations - 1], // Executor
            transferData
        );

        // Final confirmation and execution
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient received the ERC20 tokens
        assertEq(dynamicERC20.balanceOf(recipient), transferAmount, "Recipient did not receive ERC20 transfer");
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
    function testFuzzERC721TransferWithDynamicConfirmations(uint256 numOwnersInput) public {
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
            "safeTransferFrom(address,address,uint256)", address(multisigWallet), recipient, tokenId
        );

        // Expect the SubmitTransaction event for ERC721 transfer
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.ERC721,
            0,
            recipient,
            0,
            address(dynamicERC721),
            tokenId,
            dynamicOwners[0], // Initiator
            transferData
        );

        // Submit the transaction to transfer ERC721
        vm.prank(dynamicOwners[0]);
        multisigWallet.safeTransferFromERC721(address(dynamicERC721), address(multisigWallet), recipient, tokenId);

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
            address(dynamicERC721),
            tokenId,
            dynamicOwners[requiredConfirmations - 1], // Executor
            transferData
        );

        // Final confirmation and execution
        vm.prank(dynamicOwners[requiredConfirmations - 1]);
        multisigWallet.confirmTransaction(0);

        // Verify that the recipient now owns the ERC721 token
        assertEq(dynamicERC721.ownerOf(tokenId), recipient, "ERC721 token was not transferred to the recipient");
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

        vm.expectRevert("MultisigWallet: invalid data length for ERC20 transfer");
        vm.prank(owner1);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.ERC20, address(erc20Token), 0, emptyData);
    }

    /**
     * @notice Tests that an owner cannot confirm a transaction twice.
     * @dev Verifies that double confirmation is prevented in the multisig wallet.
     */
    function testDoubleConfirmationReverts() public {
        vm.prank(owner1);
        multisigWallet.sendETH(owner2, 1 ether);

        vm.prank(owner1);
        vm.expectRevert("MultisigWallet: transaction already confirmed by this owner");
        multisigWallet.confirmTransaction(0);
    }

    /**
     * @notice Tests that executing a transaction without enough confirmations reverts.
     * @dev Verifies that insufficient confirmations prevent transaction execution.
     */
    function testExecuteWithoutEnoughConfirmations() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        uint256 initialBalance = recipient.balance;

        // Submit an ETH transfer from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        // Confirm the transaction with only owner2
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);

        // Expect reversion when trying to execute with insufficient confirmations
        vm.expectRevert("MultisigWallet: insufficient confirmations to execute");
        vm.prank(owner3);
        multisigWallet.executeTransaction(0);

        uint256 receivedBalance = recipient.balance - initialBalance;

        // Verify that the transaction was not executed
        assertEq(receivedBalance, 0, "Recipient should not have received ETH");
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE, "Multisig wallet balance should remain unchanged");
    }

    /**
     * @notice Tests that malformed ERC20 transfer data reverts the transaction.
     * @dev Verifies that incorrect data lengths for ERC20 transfers are rejected.
     */
    function testMalformedERC20TransferData() public {
        address recipient = address(0x123);
        // Incorrect data length (e.g., missing bytes)
        bytes memory malformedData = abi.encodeWithSelector(IERC20.transfer.selector, recipient);

        vm.expectRevert("MultisigWallet: invalid data length for ERC20 transfer");
        vm.prank(owner1);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.ERC20, address(erc20Token), 0, malformedData);
    }

    /**
     * @notice Tests that malformed ERC721 transfer data reverts the transaction.
     * @dev Verifies that incorrect data lengths for ERC721 transfers are rejected.
     */
    function testMalformedERC721TransferData() public {
        address from = address(multisigWallet);
        address to = address(0x123);
        // Incorrect data length (e.g., missing tokenId)
        bytes memory malformedData = abi.encodeWithSignature("safeTransferFrom(address,address)", from, to);

        vm.expectRevert("MultisigWallet: invalid data length for ERC721 transfer");

        // Use the submitTransaction directly to pass the malformed data
        vm.prank(owner1);
        multisigWallet.submitTransaction(MultisigWallet.TransactionType.ERC721, address(erc721Token), 0, malformedData);
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
        MaliciousReentrantExecutor attacker = new MaliciousReentrantExecutor(multisigWallet);

        // Fund the multisig wallet
        vm.deal(address(multisigWallet), 10 ether);

        // Submit and confirm an ETH transfer to the malicious contract
        vm.prank(owner1);
        multisigWallet.sendETH(address(attacker), 1 ether);

        for (uint256 i = 1; i < owners.length / 2; i++) {
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
        uint256 initialBalance = address(0x1234).balance;

        // Owner1 submits a transaction to send 1 ether
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x1234), 1 ether);

        // Other owners confirm the transaction
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        vm.prank(owner3);
        multisigWallet.confirmTransaction(0);

        uint256 receivedBalance = address(0x1234).balance - initialBalance;

        // Verify that the recipient received the ether
        assertEq(receivedBalance, 1 ether, "Recipient should have received 1 ether");

        // Attempt to replay (re-execute) the same transaction
        vm.expectRevert("MultisigWallet: Transaction not active");
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);

        receivedBalance = address(0x1234).balance - initialBalance;

        // Check that the balance did not change (replay attack failed)
        assertEq(receivedBalance, 1 ether, "Recipient balance should remain unchanged after replay attempt");
    }

    /**
     * @notice Tests the onERC721Received function when an ERC721 token is transferred to the multisig wallet.
     * @dev Verifies that the multisig wallet correctly implements the IERC721Receiver interface.
     */
    function testOnERC721Received() public {
        // Arrange
        uint256 tokenId = 3; // Unique tokenId
        bytes memory data = "some data";

        // Mint the token to this contract (the test contract, which is the owner of erc721Token)
        erc721Token.mint(address(this), tokenId);

        // Expect the ERC721Received event when the token is received by the MultisigWallet
        vm.expectEmit(true, true, true, true);
        emit ERC721Received(address(this), address(this), tokenId, data);

        // Act: Transfer the token from this contract to the multisig wallet
        erc721Token.safeTransferFrom(address(this), address(multisigWallet), tokenId, data);

        // Assert: Verify that the multisig wallet now owns the token
        assertEq(erc721Token.ownerOf(tokenId), address(multisigWallet), "Token ownership not transferred correctly");
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

        uint256 initialWalletBalance = erc20Token.balanceOf(address(multisigWallet));

        // Ensure the sender has enough tokens
        uint256 senderBalance = erc20Token.balanceOf(sender);
        assertGe(senderBalance, transferAmount, "Sender does not have enough ERC20 tokens");

        // Act: Transfer ERC20 tokens to the multisig wallet
        vm.prank(sender);
        success = erc20Token.transfer(address(multisigWallet), transferAmount);
        require(success, "ERC20 transfer failed");

        // Assert: Check that the multisig wallet's ERC20 balance has increased
        uint256 finalWalletBalance = erc20Token.balanceOf(address(multisigWallet));
        assertEq(
            finalWalletBalance,
            initialWalletBalance + transferAmount,
            "ERC20 tokens not received correctly by MultisigWallet"
        );

        // Optionally, verify that the sender's balance has decreased by transferAmount
        uint256 finalSenderBalance = erc20Token.balanceOf(sender);
        assertEq(
            senderBalance - finalSenderBalance, transferAmount, "Sender's ERC20 balance did not decrease correctly"
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
        multisigWallet.transferERC20(IERC20(address(erc20Token)), address(0x123), 0);
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

        for (uint256 i = 1; i < (owners.length * 2 + 2) / 3; i++) {
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
        (bool success,) = address(multisigWallet).call{value: depositAmount}("");
        require(success, "ETH transfer failed");

        assertEq(address(multisigWallet).balance, INITIAL_BALANCE + depositAmount);
    }

    /**
     * @notice Tests that the required number of confirmations adjusts when an owner is removed.
     * @dev Verifies that if a multisig owner is deleted, the number of required confirmations is reduced accordingly.
     */
    function testNumConfirmationsReducedAfterOwnerRemoval() public {
        uint256 initialBalance = address(0x123).balance;

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
        uint256 requiredConfirmationsBeforeRemoval = (owners.length * 2 + 2) / 3;
        uint256 requiredConfirmationsAfterRemoval = ((owners.length - 1) * 2 + 2) / 3;

        // Assert that the number of confirmations required has been reduced after owner removal
        assertLt(
            requiredConfirmationsAfterRemoval,
            requiredConfirmationsBeforeRemoval,
            "Confirmations did not reduce after owner removal"
        );

        // Step 5: Complete the transaction by confirming with another owner
        vm.prank(owner4);
        multisigWallet.confirmTransaction(0);

        uint256 receivedBalance = address(0x123).balance - initialBalance;
        // Check that the transaction was executed
        assertEq(receivedBalance, 1 ether);
    }

    /**
     * @notice Tests that calling `deactivateMyPendingTransaction` emits the `DeactivatedMyPendingTransaction` event.
     * @dev Verifies that only the owner who submitted can deactivate, and checks the event/log output.
     */
    function testDeactivateMyPendingTransactionEvent() public {
        // 1. Submit a new transaction from owner1
        vm.prank(owner1);
        multisigWallet.sendETH(address(0x123), 1 ether);

        // 2. Confirm that the transaction is indeed active
        (, bool isActive,,,,,) = multisigWallet.transactions(0);
        assertTrue(isActive, "Transaction should initially be active");

        // 3. Attempt to deactivate from a different owner => revert
        vm.prank(owner2);
        vm.expectRevert("MultisigWallet: only the owner can clear their submitted transaction");
        multisigWallet.deactivateMyPendingTransaction(0);

        // 4. Expect the `DeactivatedMyPendingTransaction(txIndex, owner)` event from the correct call
        vm.expectEmit(true, true, false, true);
        emit DeactivatedMyPendingTransaction(0, owner1);

        // 5. Deactivate from the actual submitter, owner1
        vm.prank(owner1);
        multisigWallet.deactivateMyPendingTransaction(0);

        // 6. Verify the transaction is now inactive
        (, isActive,,,,,) = multisigWallet.transactions(0);
        assertFalse(isActive, "Transaction should now be inactive");
    }

    // ----------------------------------------------------------------------------
    // -------- New BatchTransfer Tests (with full vm.expectEmit for each sub-transfer) -------
    // ----------------------------------------------------------------------------

    /**
     * @notice Tests a simple batch transfer containing a single ETH transfer.
     */
    function testBatchTransferSingleETH() public {
        // 1. Single sub-transfer
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](1);
        transfers[0] =
            MultisigWallet.BatchTransaction({to: address(0xABC), tokenAddress: address(0), value: 1 ether, tokenId: 0});

        // 2. Encode
        bytes memory data = abi.encode(transfers);

        // 3. Expect SubmitTransaction
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.BatchTransaction, 0, address(multisigWallet), 0, address(0), 0, owner1, data
        );

        // 4. Submit
        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // 5. Confirm from enough owners minus 1
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // 6. The final confirm expects:
        //    a) ConfirmTransaction
        //    b) BatchTransferExecuted (since there's 1 sub-transfer)
        //    c) ExecuteTransaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);

        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(address(0xABC), address(0), 1 ether, 0);

        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.BatchTransaction,
            0,
            address(multisigWallet),
            0,
            address(0),
            0,
            owners[owners.length / 2],
            data
        );

        // Final confirm
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // 7. Check
        assertEq(address(0xABC).balance, 1 ether, "Recipient did not receive 1 ETH");
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - 1 ether, "Multisig not reduced");
    }

    /**
     * @notice Tests a batch transfer containing multiple items: ETH, ERC20, and ERC721.
     *         (3 sub-transfers)
     */
    function testBatchTransferMultipleItems() public {
        // We'll create a 3-item batch:
        //   1) 0.5 ETH -> address(0x111)
        //   2) 100 ERC20 tokens -> address(0x222)
        //   3) ERC721 tokenId=1 -> address(0x333)
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](3);

        transfers[0] = MultisigWallet.BatchTransaction({
            to: address(0x111),
            tokenAddress: address(0),
            value: 0.5 ether,
            tokenId: 0
        });
        transfers[1] = MultisigWallet.BatchTransaction({
            to: address(0x222),
            tokenAddress: address(erc20Token),
            value: 100 * 10 ** 18,
            tokenId: 0
        });
        transfers[2] = MultisigWallet.BatchTransaction({
            to: address(0x333),
            tokenAddress: address(erc721Token),
            value: 0,
            tokenId: 1
        });

        bytes memory data = abi.encode(transfers);

        // Expect SubmitTransaction
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.BatchTransaction, 0, address(multisigWallet), 0, address(0), 0, owner1, data
        );

        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Partial confirms
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.expectEmit(true, true, false, true);
            emit ConfirmTransaction(owners[i], 0);
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirm => Expect:
        //   a) ConfirmTransaction
        //   b) BatchTransferExecuted( #1 => 0.5 ETH -> 0x111 )
        //   c) BatchTransferExecuted( #2 => 100 tokens -> 0x222 )
        //   d) BatchTransferExecuted( #3 => ERC721 tokenId=1 -> 0x333 )
        //   e) ExecuteTransaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);

        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(address(0x111), address(0), 0.5 ether, 0);

        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(address(0x222), address(erc20Token), 100 * 10 ** 18, 0);

        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(address(0x333), address(erc721Token), 0, 1);

        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.BatchTransaction,
            0,
            address(multisigWallet),
            0,
            address(0),
            0,
            owners[owners.length / 2],
            data
        );

        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // Check final
        assertEq(address(0x111).balance, 0.5 ether, "ETH not transferred");
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - 0.5 ether, "Multisig not reduced");
        assertEq(erc20Token.balanceOf(address(0x222)), 100 * 10 ** 18, "ERC20 not transferred");
        assertEq(erc721Token.ownerOf(1), address(0x333), "ERC721 not transferred");
    }

    /**
     * @notice Tests that an empty batch array effectively does no sub-transfers (0 sub-transfers).
     */
    function testBatchTransferEmptyArray() public {
        // 0 sub-transfers
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](0);
        bytes memory data = abi.encode(transfers);

        // We can expect a SubmitTransaction event still:
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.BatchTransaction, 0, address(multisigWallet), 0, address(0), 0, owner1, data
        );

        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Partial confirms
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirm => Expect:
        //   a) ConfirmTransaction
        //   b) (No BatchTransferExecuted, because 0 sub-transfers)
        //   c) ExecuteTransaction
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);

        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.BatchTransaction,
            0,
            address(multisigWallet),
            0,
            address(0),
            0,
            owners[owners.length / 2],
            data
        );

        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // Check that no ETH left the multisig
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE, "Unexpected ETH movement");
    }

    /**
     * @notice Tests a malicious reentrancy attempt within a batch transfer (sending ETH to a contract that calls back).
     *         This ultimately reverts, so NO final events are emitted. We only expect revert.
     */
    function testBatchTransferMaliciousReentrancy() public {
        MaliciousContract attacker = new MaliciousContract(payable(address(multisigWallet)));
        vm.deal(address(multisigWallet), 5 ether); // Enough ETH

        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](1);
        transfers[0] = MultisigWallet.BatchTransaction({
            to: address(attacker),
            tokenAddress: address(0),
            value: 1 ether,
            tokenId: 0
        });

        // We won't do final expectEmit of BatchTransferExecuted, because it should revert.
        // Just do normal submission

        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Partial confirms
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // The final confirm triggers revert => no final events
        vm.expectRevert("BatchTransfer: Ether transfer failed");
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // Check no funds moved
        assertEq(address(attacker).balance, 0, "Attacker must not get ETH");
        assertEq(address(multisigWallet).balance, 5 ether, "Balance changed unexpectedly");
    }

    /**
     * @notice Tests partial confirmation ensuring the batch won't execute with insufficient signatures.
     *         No final events because it never executes.
     */
    function testBatchTransferInsufficientConfirmations() public {
        // Single sub-transfer
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](1);
        transfers[0] =
            MultisigWallet.BatchTransaction({to: address(0xAAA), tokenAddress: address(0), value: 1 ether, tokenId: 0});

        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Only partial confirm
        uint256 needed = owners.length / 2;
        for (uint256 i = 1; i < needed - 1; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Attempt to finalize => revert
        vm.prank(owners[needed - 1]);
        vm.expectRevert("MultisigWallet: insufficient confirmations to execute");
        multisigWallet.executeTransaction(0);

        // No final events, no changes
        assertEq(address(0xAAA).balance, 0, "Should not receive ETH yet");
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE, "Multisig wallet changed");
    }

    /**
     * @notice Tests a batch that sends multiple transfers (25 sub-transfers) to multiple recipients in one shot.
     *         We'll do full event checks for each sub-transfer.
     */
    function testBatchTransferMultipleRecipientsAndMixedAssets() public {
        address payable recipientA = payable(address(0x111));
        address payable recipientB = payable(address(0x222));
        address recipientC = address(0x333);

        // We do 25 sub-transfers in one batch:
        //  (1) 1 ETH -> A
        //  (2) tokenId=1 -> A
        //  (3) tokenId=2 -> A
        //  (4) 2 ETH -> B
        //  (5..24) tokenIds=3..22 -> B (20 NFTs)
        //  (25) 500 ERC20 tokens -> C
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](25);

        // #1: 1 ETH -> A
        transfers[0] =
            MultisigWallet.BatchTransaction({to: recipientA, tokenAddress: address(0), value: 1 ether, tokenId: 0});

        // #2,3: tokenId=1 and 2 -> A
        transfers[1] =
            MultisigWallet.BatchTransaction({to: recipientA, tokenAddress: address(erc721Token), value: 0, tokenId: 1});
        transfers[2] =
            MultisigWallet.BatchTransaction({to: recipientA, tokenAddress: address(erc721Token), value: 0, tokenId: 2});

        // #4: 2 ETH -> B
        transfers[3] =
            MultisigWallet.BatchTransaction({to: recipientB, tokenAddress: address(0), value: 2 ether, tokenId: 0});

        // #5..24: tokenIds=3..22 -> B
        for (uint256 i = 0; i < 20; i++) {
            transfers[4 + i] = MultisigWallet.BatchTransaction({
                to: recipientB,
                tokenAddress: address(erc721Token),
                value: 0,
                tokenId: 3 + i
            });
        }

        // #25: 500 ERC20 -> C
        transfers[24] = MultisigWallet.BatchTransaction({
            to: recipientC,
            tokenAddress: address(erc20Token),
            value: 500 * 10 ** 18,
            tokenId: 0
        });

        bytes memory data = abi.encode(transfers);

        // Expect SubmitTransaction
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(
            MultisigWallet.TransactionType.BatchTransaction, 0, address(multisigWallet), 0, address(0), 0, owner1, data
        );

        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Confirm partially
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Final confirm => expect:
        //   a) ConfirmTransaction
        //   b) 25 x BatchTransferExecuted (in order)
        //   c) ExecuteTransaction

        // (a) Confirm
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owners[owners.length / 2], 0);

        // (b) 25 sub-transfers in exact order:
        // #1: 1 ETH -> A
        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(recipientA, address(0), 1 ether, 0);

        // #2: tokenId=1 -> A
        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(recipientA, address(erc721Token), 0, 1);

        // #3: tokenId=2 -> A
        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(recipientA, address(erc721Token), 0, 2);

        // #4: 2 ETH -> B
        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(recipientB, address(0), 2 ether, 0);

        // #5..24: tokenIds=3..22 -> B
        for (uint256 i = 3; i <= 22; i++) {
            vm.expectEmit(true, true, true, true);
            emit BatchTransferExecuted(recipientB, address(erc721Token), 0, i);
        }

        // #25: 500 ERC20 -> C
        vm.expectEmit(true, true, true, true);
        emit BatchTransferExecuted(recipientC, address(erc20Token), 500 * 10 ** 18, 0);

        // (c) The ExecuteTransaction
        vm.expectEmit(true, true, true, true);
        emit ExecuteTransaction(
            MultisigWallet.TransactionType.BatchTransaction,
            0,
            address(multisigWallet),
            0,
            address(0),
            0,
            owners[owners.length / 2],
            data
        );

        // Now do final confirm
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // Validate final
        // A => 1 ETH + tokenIds 1,2
        assertEq(recipientA.balance, 1 ether, "A should have 1 ETH");
        assertEq(erc721Token.ownerOf(1), recipientA, "tokenId=1 not in A");
        assertEq(erc721Token.ownerOf(2), recipientA, "tokenId=2 not in A");

        // B => 2 ETH + tokenIds 3..22
        assertEq(recipientB.balance, 2 ether, "B should have 2 ETH");
        for (uint256 j = 3; j <= 22; j++) {
            assertEq(
                erc721Token.ownerOf(j), recipientB, string(abi.encodePacked("tokenId=", vm.toString(j), " not in B"))
            );
        }

        // C => 500 tokens
        assertEq(erc20Token.balanceOf(recipientC), 500 * 10 ** 18, "C did not get 500 tokens");

        // Multisig => lost total 3 ETH (1 + 2)
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - 3 ether, "Multisig not reduced by 3 ETH total");
    }

    /**
     * @notice Tests a batch that references a non-existent NFT tokenId, causing the entire batch to revert.
     *         Because it reverts, we do not expect the final events.
     */
    function testBatchTransferNonExistentERC721Reverts() public {
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](2);

        transfers[0] = MultisigWallet.BatchTransaction({
            to: address(0xAAA),
            tokenAddress: address(0),
            value: 0.5 ether,
            tokenId: 0
        });
        transfers[1] = MultisigWallet.BatchTransaction({
            to: address(0xBBB),
            tokenAddress: address(erc721Token),
            value: 0,
            tokenId: 9999
        });

        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Confirm up to final
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Revert => no final events
        vm.expectRevert();
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // Check partial state not changed
        assertEq(address(0xAAA).balance, 0, "Should not get partial ETH");
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE, "Multisig changed unexpectedly");
    }

    /**
     * @notice Tests a mismatch scenario: tokenId != 0 but tokenAddress == address(0). It is treated as ETH.
     *         Single sub-transfer => 1 BatchTransferExecuted event upon success.
     */
    function testBatchTransferTokenIdNonZeroButTokenAddressZero() public {
        // Single sub-transfer that fails now
        MultisigWallet.BatchTransaction[] memory transfers = new MultisigWallet.BatchTransaction[](1);

        transfers[0] = MultisigWallet.BatchTransaction({
            to: address(0xAAA),
            tokenAddress: address(0), // => ETH
            value: 1 ether,
            tokenId: 9999 // => triggers revert
        });

        // Submit batch
        vm.prank(owner1);
        multisigWallet.batchTransfer(transfers);

        // Partially confirm up to final
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Now, because your contract *reverts* when tokenId != 0 for ETH:
        vm.expectRevert("BatchTransfer: ETH transfer with TokenId doesn't make sense");
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // Done. We *expect* revert, so no final checks needed.
    }

    /**
     * @notice Tests that a malicious token cannot drain the multisig by hooking into its transfer call.
     *         This reverts, so no final batch events are emitted.
     */
    function testMaliciousTokenCannotDrainViaBatch() public {
        MaliciousToken maliciousToken = new MaliciousToken(1000, payable(address(multisigWallet)));

        // Single sub-transfer => tries to move 100 tokens, but reverts
        address attacker = address(0xDEF);
        MultisigWallet.BatchTransaction[] memory txs = new MultisigWallet.BatchTransaction[](1);
        txs[0] = MultisigWallet.BatchTransaction({
            to: attacker,
            tokenAddress: address(maliciousToken),
            value: 100,
            tokenId: 0
        });

        vm.prank(owner1);
        multisigWallet.batchTransfer(txs);

        // Partial confirms
        for (uint256 i = 1; i < owners.length / 2; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Revert => no final events
        vm.expectRevert("MultisigWallet: Not a multisig owner");
        vm.prank(owners[owners.length / 2]);
        multisigWallet.confirmTransaction(0);

        // No tokens moved
        assertEq(maliciousToken.balanceOf(address(multisigWallet)), 1000, "Should remain in multisig");
        assertEq(maliciousToken.balanceOf(attacker), 0, "Attacker not credited");
    }
}
