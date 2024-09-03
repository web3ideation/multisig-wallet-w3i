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

    function setUp() public {
        owners = [owner1, owner2, owner3, owner4, owner5];
        multisigWallet = new MultisigWallet(owners);
        erc20Token = new SimpleERC20(ERC20_INITIAL_SUPPLY);
        erc721Token = new SimpleERC721();

        // Fund the multisig wallet
        vm.deal(address(multisigWallet), INITIAL_BALANCE);

        // Transfer some ERC20 tokens to the multisig wallet
        erc20Token.transfer(address(multisigWallet), 1000 * 10 ** 18);

        // Mint two ERC721 tokens to the multisig wallet
        erc721Token.mint(address(multisigWallet), 1);
        erc721Token.mint(address(multisigWallet), 2);
    }

    function testDeposit() public {
        uint256 depositAmount = 1 ether;
        address depositor = address(0x123);
        vm.deal(depositor, depositAmount);

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

        // Submit transaction
        vm.prank(owner1);
        multisigWallet.addOwner(newOwner);

        // Confirm transaction
        for (uint i = 0; i < 5; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the owner was added
        assertTrue(multisigWallet.isOwner(newOwner));
        assertEq(multisigWallet.getOwnerCount(), 6);
    }

    function testRemoveOwner() public {
        // Submit transaction
        vm.prank(owner1);
        multisigWallet.removeOwner(owner5);

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the owner was removed
        assertFalse(multisigWallet.isOwner(owner5));
        assertEq(multisigWallet.getOwnerCount(), 4);
    }

    function testSubmitAndConfirmETHTransaction() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        // Submit transaction
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ETH,
            recipient,
            amount,
            ""
        );

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the ETH was transferred
        assertEq(recipient.balance, amount);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - amount);
    }

    function testSubmitAndConfirmERC20Transaction() public {
        address recipient = address(0x123);
        uint256 amount = 100 * 10 ** 18;

        uint256 initialBalance = erc20Token.balanceOf(address(multisigWallet));

        // Submit transaction
        vm.prank(owner1);
        multisigWallet.safeTransferERC20(
            IERC20(address(erc20Token)),
            recipient,
            amount
        );

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the tokens were transferred
        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(
            erc20Token.balanceOf(address(multisigWallet)),
            initialBalance - amount
        );
    }

    function testSubmitAndConfirmERC721Transaction() public {
        address recipient = address(0x123);
        uint256 tokenId = 1;

        // Ensure the multisig wallet owns the token
        assertEq(erc721Token.ownerOf(tokenId), address(multisigWallet));

        // Submit transaction
        vm.prank(owner1);
        multisigWallet.transferERC721(address(erc721Token), recipient, tokenId);

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the NFT was transferred
        assertEq(erc721Token.ownerOf(tokenId), recipient);
    }

    function testRevokeConfirmation() public {
        // Submit transaction
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ETH,
            payable(address(0x123)),
            1 ether,
            ""
        );

        // Confirm transaction
        for (uint i = 0; i < 3; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Revoke confirmation
        vm.prank(owner1);
        multisigWallet.revokeConfirmation(0);

        // Try to confirm again
        vm.prank(owner4);
        multisigWallet.confirmTransaction(0);

        // Transaction should not be executed due to revoked confirmation
        assertEq(address(0x123).balance, 0);
    }

    function testFailExecuteWithInsufficientConfirmations() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        // Submit transaction
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.ETH,
            recipient,
            amount,
            ""
        );

        // Confirm transaction (but not enough)
        for (uint i = 0; i < 3; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check that the transaction wasn't executed
        assertEq(recipient.balance, 0);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE);

        // Try to confirm again (this should execute the transaction if there were enough confirmations)
        vm.prank(owner4);
        multisigWallet.confirmTransaction(0);

        // Check that the transaction still wasn't executed
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
        // Deploy a simple counter contract
        SimpleCounter counter = new SimpleCounter();

        // Submit transaction to increment counter
        bytes memory data = abi.encodeWithSignature("increment()");
        vm.prank(owner1);
        multisigWallet.submitTransaction(
            MultisigWallet.TransactionType.Other,
            address(counter),
            0,
            data
        );

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the counter was incremented
        assertEq(counter.count(), 1);
    }

    function testSendETH() public {
        address payable recipient = payable(address(0x123));
        uint256 amount = 1 ether;

        // Submit transaction using sendETH
        vm.prank(owner1);
        multisigWallet.sendETH(recipient, amount);

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if the ETH was transferred
        assertEq(recipient.balance, amount);
        assertEq(address(multisigWallet).balance, INITIAL_BALANCE - amount);
    }

    function testFailAddExistingOwner() public {
        // Try to add an existing owner
        vm.prank(owner1);
        multisigWallet.addOwner(owner2);

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }
    }

    function testFailRemoveLastOwner() public {
        // Remove all owners except one
        for (uint i = 1; i < owners.length; i++) {
            vm.prank(owner1);
            multisigWallet.removeOwner(owners[i]);

            // Confirm transaction with the remaining owners
            for (uint j = 0; j < owners.length - i; j++) {
                vm.prank(owners[j]);
                multisigWallet.confirmTransaction(i - 1);
            }
        }

        // Try to remove the last owner (should fail)
        vm.prank(owner1);
        vm.expectRevert("Cannot remove last owner");
        multisigWallet.removeOwner(owner1);
    }

    function testUpdateConfirmationsRequired() public {
        // Get initial confirmations required
        uint256 initialNormalConfirmations = multisigWallet
            .numNormalDecisionConfirmations();
        uint256 initialImportantConfirmations = multisigWallet
            .numImportantDecisionConfirmations();

        // Remove an owner
        vm.prank(owner1);
        multisigWallet.removeOwner(owner5);

        // Confirm transaction
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            multisigWallet.confirmTransaction(0);
        }

        // Check if confirmations required were updated
        uint256 newNormalConfirmations = multisigWallet
            .numNormalDecisionConfirmations();
        uint256 newImportantConfirmations = multisigWallet
            .numImportantDecisionConfirmations();

        assertEq(newNormalConfirmations, initialNormalConfirmations - 1);
        assertEq(newImportantConfirmations, initialImportantConfirmations - 1);
    }
}

// Simple counter contract for testing "Other" transaction type
contract SimpleCounter {
    uint public count;

    function increment() public {
        count += 1;
    }
}
