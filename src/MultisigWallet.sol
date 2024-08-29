// SPDX-License-Identifier: MIT
// This file is part of the MultisigWallet project.
// Portions of this code are derived from the OpenZeppelin Contracts library.
// OpenZeppelin Contracts are licensed under the MIT License.
// See the LICENSE file for more details.
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title MultisigWallet
 * @dev A multisig wallet contract that requires multiple confirmations for transactions, including managing owners.
 */
contract MultisigWallet is ReentrancyGuard, IERC721Receiver {
    /// @notice Emitted when a deposit is made.
    /// @param sender The address that sent the deposit.
    /// @param amountOrTokenId The amount of the deposit.
    /// @param balance The new balance of the wallet.
    event Deposit(
        address indexed sender,
        uint256 amountOrTokenId,
        uint256 balance
    );

    /// @notice Emitted when a transaction is submitted.
    /// @param txIndex The index of the submitted transaction.
    /// @param to The address to which the transaction is sent.
    /// @param value The amount of Ether sent in the transaction.
    /// @param data The data sent with the transaction.
    /// @param owner The address of the owner who submitted the transaction.
    event SubmitTransaction(
        TransactionType indexed _transactionType,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data,
        address tokenAddress,
        uint256 amountOrTokenId,
        address owner
    );

    /// @notice Emitted when a transaction is confirmed.
    /// @param owner The address of the owner who confirmed the transaction.
    /// @param txIndex The index of the confirmed transaction.
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);

    /// @notice Emitted when a confirmation is revoked.
    /// @param owner The address of the owner who revoked the confirmation.
    /// @param txIndex The index of the transaction for which the confirmation was revoked.
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);

    /// @notice Emitted when a transaction is executed.
    /// @param owner The address of the owner who executed the transaction.
    /// @param txIndex The index of the executed transaction.
    event ExecuteTransaction(
        TransactionType indexed _transactionType,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data,
        address tokenAddress,
        uint256 amountOrTokenId,
        address owner
    );

    /// @notice Emitted when an owner is added.
    /// @param owner The address of the owner added.
    event OwnerAdded(address indexed owner);

    /// @notice Emitted when an owner is removed.
    /// @param owner The address of the owner removed.
    event OwnerRemoved(address indexed owner);

    /// @notice Emitted when all pending transactions have been cleared.
    event PendingTransactionsDeactivated();

    event DeactivatedMyPendingTransaction(
        uint indexed txIndex,
        address indexed owner
    );

    using SafeERC20 for IERC20;

    enum TransactionType {
        ETH,
        ERC20,
        ERC721,
        AddOwner,
        RemoveOwner,
        Other
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numImportantDecisionConfirmations;
    uint256 public numNormalDecisionConfirmations;

    struct Transaction {
        TransactionType transactionType;
        address to;
        uint256 value;
        bytes data;
        bool isActive;
        uint256 numConfirmations;
        address owner;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;

    modifier onlyMultisigOwner() {
        require(isOwner[msg.sender], "Not a multisig owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier isActive(uint256 _txIndex) {
        require(transactions[_txIndex].isActive, "Transaction not active");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "Transaction already confirmed"
        );
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _owners The addresses of the owners.
     */
    constructor(address[] memory _owners) {
        require(_owners.length > 0, "Owners required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        updateConfirmationsRequired();
    }

    /**
     * @dev Fallback function to receive Ether.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Submits a transaction to be confirmed by the owners.
     * @param _to The address to send the transaction to.
     * @param _value The amount of Ether to send.
     * @param _data The data to send with the transaction.
     */
    function submitTransaction(
        TransactionType _transactionType,
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyMultisigOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                transactionType: _transactionType,
                to: _to,
                value: _value,
                data: _data,
                isActive: true,
                numConfirmations: 0,
                owner: msg.sender //!!! is this fine or do i have to assign the msg.sender to a variable before the transaction.push?
            })
        );

        // Decode the data to extract the token address and amount / tokenId
        (address tokenAddress, uint256 amountOrTokenId) = decodeTransactionData(
            _data
        );

        emit SubmitTransaction(
            _transactionType,
            txIndex,
            _to,
            _value,
            _data,
            tokenAddress, //!!! whats this when the proposal is just about sending ETH without ERC20 or ERC721?
            amountOrTokenId, //!!! whats this when the proposal is just about sending ETH without ERC20 or ERC721?
            msg.sender
        );
    }

    /**
     * @dev Confirms a submitted transaction.
     * @param _txIndex The index of the transaction to confirm.
     */
    function confirmTransaction(
        uint256 _txIndex
    )
        public
        onlyMultisigOwner
        txExists(_txIndex)
        isActive(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);

        //!!! when i have a working logic for the 50%+1 and 2/3 numConfirmationsRequired I should use this commented out code (tho make sure that for the case of removeOwner only owners.length -1 is required so that the to be removed owner doesnt have a veto)
        // uint256 numConfirmationsRequired = (transaction.transactionType ==
        //     TransactionType.AddOwner ||
        //     transaction.transactionType == TransactionType.RemoveOwner)
        //     ? numImportantDecisionConfirmations
        //     : numNormalDecisionConfirmations;

        uint256 numConfirmationsRequired;
        if (transaction.transactionType == TransactionType.AddOwner) {
            numConfirmationsRequired = numImportantDecisionConfirmations;
        } else if (transaction.transactionType == TransactionType.RemoveOwner) {
            if (owners.length == 2) {
                numConfirmationsRequired = numImportantDecisionConfirmations;
            } else {
                numConfirmationsRequired =
                    numImportantDecisionConfirmations -
                    1;
            }
        } else {
            numConfirmationsRequired = numNormalDecisionConfirmations;
        }

        if (transaction.numConfirmations >= numConfirmationsRequired) {
            executeTransaction(_txIndex);
        }
    }

    /**
     * @dev Executes a confirmed transaction.
     * @param _txIndex The index of the transaction to execute.
     */
    function executeTransaction(
        uint256 _txIndex
    )
        internal
        onlyMultisigOwner
        txExists(_txIndex)
        isActive(_txIndex)
        nonReentrant
    {
        Transaction storage transaction = transactions[_txIndex];

        //!!! when i have a working logic for the 50%+1 and 2/3 numConfirmationsRequired I should use this commented out code (tho make sure that for the case of removeOwner only owners.length -1 is required so that the to be removed owner doesnt have a veto)
        // uint256 numConfirmationsRequired = (transaction.transactionType ==
        //     TransactionType.AddOwner ||
        //     transaction.transactionType == TransactionType.RemoveOwner)
        //     ? numImportantDecisionConfirmations
        //     : numNormalDecisionConfirmations;

        uint256 numConfirmationsRequired;
        if (transaction.transactionType == TransactionType.AddOwner) {
            numConfirmationsRequired = numImportantDecisionConfirmations;
        } else if (transaction.transactionType == TransactionType.RemoveOwner) {
            if (owners.length == 2) {
                numConfirmationsRequired = numImportantDecisionConfirmations;
            } else {
                numConfirmationsRequired =
                    numImportantDecisionConfirmations -
                    1;
            }
        } else {
            numConfirmationsRequired = numNormalDecisionConfirmations;
        }

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Not enough Confirmations"
        );

        if (transaction.transactionType == TransactionType.AddOwner) {
            addOwnerInternal(transaction.to);
        } else if (transaction.transactionType == TransactionType.RemoveOwner) {
            removeOwnerInternal(transaction.to);
        } else {
            (bool success, ) = transaction.to.call{value: transaction.value}(
                transaction.data
            );
            require(success, "Transaction failed"); // if the transaction failed, will the transaction.executed still be true?
        }

        transaction.isActive = false;

        // Decode the data to extract the token address and amount / tokenId
        (address tokenAddress, uint256 amountOrTokenId) = decodeTransactionData(
            transaction.data
        );

        emit ExecuteTransaction(
            transaction.transactionType,
            _txIndex,
            transaction.to,
            transaction.value,
            transaction.data,
            tokenAddress,
            amountOrTokenId,
            msg.sender
        );

        //!!! Should the transaction[txIndex] be deleted after the execution? just to keep everything clean you know since we delete every once in a while when we add or remove owners or somebody actively revokes their proposal ... ?
    }

    /**
     * @dev Revokes a confirmation for a transaction.
     * @param _txIndex The index of the transaction to revoke confirmation for.
     */
    function revokeConfirmation(
        uint256 _txIndex
    ) public onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender], "Transaction not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function sendETH(address _to, uint256 _amount) public onlyMultisigOwner {
        submitTransaction(TransactionType.ETH, _to, _amount, "");
    }

    /**
     * @dev Adds a new multisig owner. This function needs to be confirmed by the required number of owners.
     * @param _newOwner The address of the new owner.
     */

    function addOwner(address _newOwner) public onlyMultisigOwner {
        //!!! I think this should be added here aswell require(_newOwner != address(0), "Invalid owner");
        require(!isOwner[_newOwner], "Owner already exists");
        submitTransaction(TransactionType.AddOwner, _newOwner, 0, "");
    }

    /**
     * @dev Internal function to add a new owner. Should only be called via a confirmed transaction.
     * @param _newOwner The address of the new owner.
     */
    function addOwnerInternal(
        address _newOwner
    )
        internal
        onlyMultisigOwner
        txExists(transactions.length - 1)
        isActive(transactions.length - 1)
    {
        //!!! also add a check that the importantNumconfirmation is used, since maybe a malicious proposer could try to use the "other"enum to propose an add or remove owner whith only the normalnumconfirmation required.
        require(_newOwner != address(0), "Invalid owner");
        require(!isOwner[_newOwner], "Owner already exists");

        // Clear pending transactions before adding the new owner
        deactivatePendingTransactions();

        isOwner[_newOwner] = true;
        owners.push(_newOwner);

        updateConfirmationsRequired(); // is this voulnerable to a reentrnacy attack?

        emit OwnerAdded(_newOwner);
    }

    /**
     * @dev Removes a multisig owner. This function needs to be confirmed by the required number of owners.
     * @param _owner The address of the owner to remove.
     */
    function removeOwner(address _owner) public onlyMultisigOwner {
        //!!! i thin this should be added here as well         require(isOwner[_owner], "Not an owner");

        submitTransaction(TransactionType.RemoveOwner, _owner, 0, "");
    }

    /**
     * @dev Internal function to remove an owner. Should only be called via a confirmed transaction.
     * @param _owner The address of the owner to remove.
     */
    function removeOwnerInternal(
        address _owner
    )
        internal
        onlyMultisigOwner
        txExists(transactions.length - 1)
        isActive(transactions.length - 1)
    {
        //!!! also add a check that the importantNumconfirmation is used, since maybe a malicious proposer could try to use the "other"enum to propose an add or remove owner whith only the normalnumconfirmation required.
        require(isOwner[_owner], "Not an owner");

        // Clear pending transactions before adding the new owner
        deactivatePendingTransactions();

        isOwner[_owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        updateConfirmationsRequired();

        emit OwnerRemoved(_owner);
        //!!! doublecheck that if a multisigowner gets deleted that the numconfirmation gets reduced in case otherwise there would be more confirmations required than multisigowners exist.
    }

    // Safe ERC20 transfer function
    function safeTransferERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) public onlyMultisigOwner {
        // Encode the transfer data
        bytes memory data = abi.encodeWithSelector(
            token.transfer.selector,
            to,
            amount
        );
        // Submit the transaction for confirmation
        submitTransaction(TransactionType.ERC20, address(token), 0, data);
    }

    // Safe ERC20 transferFrom function
    function safeTransferFromERC20(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) public onlyMultisigOwner {
        // Encode the transferFrom data
        bytes memory data = abi.encodeWithSelector(
            token.transferFrom.selector,
            from,
            to,
            amount
        );
        // Submit the transaction for confirmation
        submitTransaction(TransactionType.ERC20, address(token), 0, data);
    }

    /**
     * @dev Submits a transaction to transfer ERC721 tokens.
     * @param _tokenAddress The address of the ERC721 token contract.
     * @param _to The address to send the token to.
     * @param _tokenId The ID of the token to send.
     */
    function transferERC721(
        address _tokenAddress,
        address _to,
        uint256 _tokenId
    ) public onlyMultisigOwner {
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(this),
            _to,
            _tokenId
        );
        submitTransaction(TransactionType.ERC721, _tokenAddress, 0, data);
    }

    function deactivatePendingTransactions() internal {
        for (uint256 i = 0; i < transactions.length; i++) {
            if (transactions[i].isActive) {
                transactions[i].isActive = false;
            }
        }
        emit PendingTransactionsDeactivated();
    }

    function deactivateMyPendingTransaction(
        uint _txIndex
    ) public txExists(_txIndex) isActive(_txIndex) {
        require(
            transactions[_txIndex].owner == msg.sender,
            "Only the owner can clear their transaction"
        );

        // Deactivate Transaction
        transactions[_txIndex].isActive = false;

        emit DeactivatedMyPendingTransaction(_txIndex, msg.sender);
    }

    function decodeTransactionData(
        bytes memory data
    ) internal pure returns (address tokenAddress, uint256 amountOrTokenId) {
        bytes4 erc20Selector = bytes4(keccak256("transfer(address,uint256)"));
        bytes4 erc721Selector = bytes4(
            keccak256("safeTransferFrom(address,address,uint256)")
        );

        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        // since we don't need the isERC721 anymore because we have the enum, check what is exactly necessary in this function for extracting the info of token address and amount/id
        if (selector == erc20Selector) {
            require(
                data.length == 68,
                "Invalid data length for ERC20 transfer"
            );
            address _to;
            uint256 _amountOrTokenId;
            assembly {
                _to := mload(add(data, 36))
                _amountOrTokenId := mload(add(data, 68))
            }
            return (_to, _amountOrTokenId);
        } else if (selector == erc721Selector) {
            require(
                data.length == 100,
                "Invalid data length for ERC721 transfer"
            );
            address _from;
            address _to;
            uint256 tokenId;
            assembly {
                _from := mload(add(data, 36))
                _to := mload(add(data, 68))
                tokenId := mload(add(data, 100))
            }
            return (_to, tokenId);
        } else {
            return (address(0), 0);
        }
    }

    function updateConfirmationsRequired() internal {
        uint256 ownerCount = owners.length;
        // numNormalDecisionConfirmations = (ownerCount + 1) / 2; // !!! these don't really work so i am using a simple approach for now
        // numImportantDecisionConfirmations = (2 * ownerCount + 2) / 3; // !!! these don't really work so i am using a simple approach for now
        if (ownerCount > 2) {
            numNormalDecisionConfirmations = ownerCount - 1;
            numImportantDecisionConfirmations = ownerCount;
        } else {
            numNormalDecisionConfirmations = ownerCount;
            numImportantDecisionConfirmations = ownerCount;
        }
        require(
            ownerCount >= numNormalDecisionConfirmations,
            "numNormalDecisionConfirmations higher then owners"
        );
        require(
            ownerCount >= numImportantDecisionConfirmations,
            "numImportantDecisionConfirmations higher then owners"
        );
    }

    // IERC721Receiver implementation
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function getOwnerCount() public view returns (uint256) {
        uint256 ownerCount = owners.length;
        return ownerCount;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}
