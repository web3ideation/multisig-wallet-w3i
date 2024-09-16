// SPDX-License-Identifier: MIT
// This file is part of the MultisigWallet project.
// Portions of this code are derived from the OpenZeppelin Contracts library.
// OpenZeppelin Contracts are licensed under the MIT License.
// See the LICENSE file for more details.
pragma solidity ^0.8.7;

import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

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

    struct Transaction {
        TransactionType transactionType;
        bool isActive;
        uint64 numConfirmations;
        address owner;
        address to;
        uint256 value;
        bytes data;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;

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
                owner: msg.sender
            })
        );

        address recipient = _to;
        address tokenAddress = address(0);
        uint256 _amountOrTokenId = 0;

        if (
            _transactionType == TransactionType.ERC20 ||
            _transactionType == TransactionType.ERC721
        ) {
            // Decode the data to extract the token address and amount / tokenId
            (address to, uint256 amountOrTokenId) = decodeTransactionData(
                _transactionType,
                _data
            );
            recipient = to;
            tokenAddress = _to;
            _amountOrTokenId = amountOrTokenId;
        }

        emit SubmitTransaction(
            _transactionType,
            txIndex,
            recipient,
            _value,
            _data,
            tokenAddress,
            _amountOrTokenId,
            msg.sender
        );

        confirmTransaction(txIndex);
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
        isConfirmed[_txIndex][msg.sender] = true;
        uint64 newNumConfirmations = transaction.numConfirmations + 1; // doing that to safe gas
        transaction.numConfirmations = newNumConfirmations;

        TransactionType txType = transaction.transactionType; // doing that to safe gas in the hasEnoughConfirmations function

        emit ConfirmTransaction(msg.sender, _txIndex);

        if (hasEnoughConfirmations(newNumConfirmations, txType)) {
            executeTransaction(_txIndex); // this means that the owner who gives the last needed confirmation has to pay for the execution gas fees
        }
    }

    /**
     * @dev Executes a confirmed transaction.
     * @param _txIndex The index of the transaction to execute.
     */
    function executeTransaction(
        uint256 _txIndex
    ) internal txExists(_txIndex) isActive(_txIndex) nonReentrant {
        Transaction storage transaction = transactions[_txIndex];

        uint64 numConfirmations = transaction.numConfirmations;
        TransactionType txType = transaction.transactionType;

        require(
            hasEnoughConfirmations(numConfirmations, txType),
            "Not enough confirmations"
        );

        address to = transaction.to;
        uint256 value = transaction.value;
        bytes memory data = transaction.data;

        if (txType == TransactionType.AddOwner) {
            addOwnerInternal(to, _txIndex);
        } else if (txType == TransactionType.RemoveOwner) {
            removeOwnerInternal(to, _txIndex);
        } else {
            (bool success, ) = to.call{value: value}(data);
            require(success, "Transaction failed");
        }

        transaction.isActive = false;

        address recipient = to;
        address tokenAddress = address(0);
        uint256 amountOrTokenId = 0;

        if (
            txType == TransactionType.ERC20 || txType == TransactionType.ERC721
        ) {
            // Decode the data to extract the token address and amount / tokenId
            (address _to, uint256 _amountOrTokenId) = decodeTransactionData(
                txType,
                transaction.data
            );
            recipient = _to;
            tokenAddress = to;
            amountOrTokenId = _amountOrTokenId;
        }

        emit ExecuteTransaction(
            txType,
            _txIndex,
            recipient,
            value,
            data,
            tokenAddress,
            amountOrTokenId,
            msg.sender
        );
    }

    /**
     * @dev Revokes a confirmation for a transaction.
     * @param _txIndex The index of the transaction to revoke confirmation for.
     */
    function revokeConfirmation(
        uint256 _txIndex
    ) public onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            isConfirmed[_txIndex][msg.sender],
            "Transaction has not been confirmed"
        );

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
        require(!isOwner[_newOwner], "Owner already exists");
        submitTransaction(TransactionType.AddOwner, _newOwner, 0, "");
    }

    /**
     * @dev Internal function to add a new owner. Should only be called via a confirmed transaction.
     * @param _newOwner The address of the new owner.
     */
    function addOwnerInternal(
        address _newOwner,
        uint256 _txIndex
    ) internal onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations * 3 >= owners.length * 2,
            "Not enough confirmations"
        );

        require(!isOwner[_newOwner], "Owner already exists");

        // Clear pending transactions before adding the new owner
        deactivatePendingTransactions();

        isOwner[_newOwner] = true;
        owners.push(_newOwner);

        emit OwnerAdded(_newOwner);
    }

    /**
     * @dev Removes a multisig owner. This function needs to be confirmed by the required number of owners.
     * @param _owner The address of the owner to remove.
     */
    function removeOwner(address _owner) public onlyMultisigOwner {
        require(isOwner[_owner], "Not an owner");
        submitTransaction(TransactionType.RemoveOwner, _owner, 0, "");
    }

    /**
     * @dev Internal function to remove an owner. Should only be called via a confirmed transaction.
     * @param _owner The address of the owner to remove.
     */
    function removeOwnerInternal(
        address _owner,
        uint256 _txIndex
    ) internal onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations * 3 >= owners.length * 2,
            "Not enough confirmations"
        );

        require(isOwner[_owner], "Not an owner");

        require(owners.length > 1, "Cannot remove the last owner");

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

        emit OwnerRemoved(_owner);
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
        address _from,
        address _to,
        uint256 _tokenId
    ) public onlyMultisigOwner {
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            _from,
            _to,
            _tokenId
        );
        submitTransaction(TransactionType.ERC721, _tokenAddress, 0, data);
    }

    function deactivatePendingTransactions() internal {
        uint256 length = transactions.length;
        for (uint256 i = 0; i < length; ) {
            Transaction storage txn = transactions[i];
            if (txn.isActive) {
                txn.isActive = false;
            }
            unchecked {
                ++i;
            }
        }
        emit PendingTransactionsDeactivated();
    }

    function deactivateMyPendingTransaction(
        uint _txIndex
    ) public txExists(_txIndex) isActive(_txIndex) onlyMultisigOwner {
        require(
            transactions[_txIndex].owner == msg.sender,
            "Only the owner can clear their submitted transaction"
        );

        // Deactivate Transaction
        transactions[_txIndex].isActive = false;

        emit DeactivatedMyPendingTransaction(_txIndex, msg.sender);
    }

    function hasEnoughConfirmations(
        uint64 numConfirmations,
        TransactionType transactionType
    ) internal view returns (bool) {
        if (
            transactionType == TransactionType.AddOwner ||
            transactionType == TransactionType.RemoveOwner
        ) {
            // Important decisions require 2/3 or more confirmations
            return numConfirmations * 3 >= owners.length * 2;
        } else {
            // Normal decisions require more than 50% confirmations
            return numConfirmations * 2 > owners.length;
        }
    }

    function decodeTransactionData(
        TransactionType transactionType,
        bytes memory data
    ) internal pure returns (address to, uint256 amountOrTokenId) {
        if (transactionType == TransactionType.ERC20) {
            // ERC20 transfer(address recipient, uint256 amount)
            require(
                data.length == 68,
                "Invalid data length for ERC20 transfer"
            );

            // Use assembly to extract parameters directly
            assembly {
                // Skip the first 36 bytes (32 bytes for length, 4 bytes for selector)
                let paramsOffset := add(data, 36)
                to := mload(paramsOffset) // Load address (recipient)
                amountOrTokenId := mload(add(paramsOffset, 32)) // Load uint256 (amount)
            }
            return (to, amountOrTokenId);
        } else if (transactionType == TransactionType.ERC721) {
            // ERC721 safeTransferFrom(address from, address to, uint256 tokenId)
            require(
                data.length == 100,
                "Invalid data length for ERC721 transfer"
            );

            // Use assembly to extract parameters directly
            assembly {
                let paramsOffset := add(data, 36)
                // Skipping 'from' address (we don't need it for the return value)
                to := mload(add(paramsOffset, 32)) // Load address (to)
                amountOrTokenId := mload(add(paramsOffset, 64)) // Load uint256 (tokenId)
            }
            return (to, amountOrTokenId);
        } else {
            return (address(0), 0);
        }
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
