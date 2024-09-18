// SPDX-License-Identifier: MIT
// This file is part of the MultisigWallet project.
// Portions of this code are derived from the OpenZeppelin Contracts library.
// OpenZeppelin Contracts are licensed under the MIT License.
// See the LICENSE and NOTICE files for more details.
pragma solidity ^0.8.7;

import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title MultisigWallet
 * @dev A multisig wallet contract that requires multiple confirmations for transactions, including managing owners.
 */
contract MultisigWallet is ReentrancyGuard, IERC721Receiver {
    /**
     * @notice Emitted when a deposit is made.
     * @param sender The address that sent the deposit.
     * @param amountOrTokenId The amount of Ether or the token ID for ERC721 deposits.
     * @param balance The new balance of the wallet after the deposit.
     */
    event Deposit(
        address indexed sender,
        uint256 amountOrTokenId,
        uint256 balance
    );

    /**
     * @notice Emitted when a transaction is submitted.
     * @param _transactionType The type of the submitted transaction.
     * @param txIndex The index of the submitted transaction.
     * @param to The address to which the transaction is directed.
     * @param value The amount of Ether sent in the transaction.
     * @param data The data payload of the transaction.
     * @param tokenAddress The address of the token contract (if applicable).
     * @param amountOrTokenId The amount of tokens or the token ID (if applicable).
     * @param owner The address of the owner who submitted the transaction.
     */
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

    /**
     * @notice Emitted when a transaction is confirmed by an owner.
     * @param owner The address of the owner who confirmed the transaction.
     * @param txIndex The index of the confirmed transaction.
     */
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);

    /**
     * @notice Emitted when a confirmation for a transaction is revoked by an owner.
     * @param owner The address of the owner who revoked the confirmation.
     * @param txIndex The index of the transaction for which the confirmation was revoked.
     */
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);

    /**
     * @notice Emitted when a transaction is executed.
     * @param _transactionType The type of the executed transaction.
     * @param txIndex The index of the executed transaction.
     * @param to The address to which the transaction was sent.
     * @param value The amount of Ether sent in the transaction.
     * @param data The data payload of the transaction.
     * @param tokenAddress The address of the token contract (if applicable).
     * @param amountOrTokenId The amount of tokens or the token ID (if applicable).
     * @param owner The address of the owner who executed the transaction.
     */
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

    /**
     * @notice Emitted when a new owner is added to the multisig wallet.
     * @param owner The address of the owner that was added.
     */
    event OwnerAdded(address indexed owner);

    /**
     * @notice Emitted when an owner is removed from the multisig wallet.
     * @param owner The address of the owner that was removed.
     */
    event OwnerRemoved(address indexed owner);

    /**
     * @notice Emitted when all pending transactions are deactivated.
     */
    event PendingTransactionsDeactivated();

    /**
     * @notice Emitted when an owner deactivates their own pending transaction.
     * @param txIndex The index of the transaction that was deactivated.
     * @param owner The address of the owner who deactivated the transaction.
     */
    event DeactivatedMyPendingTransaction(
        uint indexed txIndex,
        address indexed owner
    );

    /**
     * @notice Emitted when the contract receives an ERC721 token.
     * @param operator The address which initiated the transfer (i.e., msg.sender).
     * @param from The address which previously owned the token.
     * @param tokenId The identifier of the token being transferred.
     * @param data Additional data with no specified format.
     */
    event ERC721Received(
        address indexed operator,
        address indexed from,
        uint256 indexed tokenId,
        bytes data
    );

    /**
     * @enum TransactionType
     * @dev Represents the type of transaction in the multisig wallet.
     * @param ETH Ether transfer.
     * @param ERC20 ERC20 token transfer.
     * @param ERC721 ERC721 token transfer.
     * @param AddOwner Adding a new owner.
     * @param RemoveOwner Removing an existing owner.
     * @param Other Any other transaction type.
     */
    enum TransactionType {
        ETH,
        ERC20,
        ERC721,
        AddOwner,
        RemoveOwner,
        Other
    }

    /**
     * @struct Transaction
     * @dev Represents a transaction within the multisig wallet.
     * @param transactionType The type of the transaction.
     * @param isActive Indicates if the transaction is active.
     * @param numConfirmations The number of confirmations the transaction has received.
     * @param owner The address of the owner who submitted the transaction.
     * @param to The destination address of the transaction.
     * @param value The amount of Ether involved in the transaction.
     * @param data The data payload of the transaction.
     */
    struct Transaction {
        TransactionType transactionType;
        bool isActive;
        uint64 numConfirmations;
        address owner;
        address to;
        uint256 value;
        bytes data;
    }

    /// @notice Array of multisig wallet owners.
    address[] public owners;

    /// @notice Mapping to check if an address is an owner.
    mapping(address => bool) public isOwner;

    /// @notice Nested mapping to track confirmations: transaction index => owner => confirmation status.
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    /// @notice Array of all submitted transactions.
    Transaction[] public transactions;

    /**
     * @notice Modifier to restrict access to only multisig owners.
     * @dev Reverts if the caller is not an owner.
     */
    modifier onlyMultisigOwner() {
        require(isOwner[msg.sender], "MultisigWallet: Not a multisig owner");
        _;
    }

    /**
     * @notice Modifier to check if a transaction exists.
     * @dev Reverts if the transaction does not exist.
     * @param _txIndex The index of the transaction.
     */
    modifier txExists(uint256 _txIndex) {
        require(
            _txIndex < transactions.length,
            "MultisigWallet: Transaction does not exist"
        );
        _;
    }

    /**
     * @notice Modifier to check if a transaction is active.
     * @dev Reverts if the transaction is not active.
     * @param _txIndex The index of the transaction.
     */
    modifier isActive(uint256 _txIndex) {
        require(
            transactions[_txIndex].isActive,
            "MultisigWallet: Transaction not active"
        );
        _;
    }

    /**
     * @notice Modifier to ensure the transaction has not been confirmed by the caller.
     * @dev Reverts if the transaction is already confirmed by the caller.
     * @param _txIndex The index of the transaction.
     */
    modifier notConfirmed(uint256 _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "MultisigWallet: transaction already confirmed by this owner"
        );
        _;
    }

    /**
     * @notice Initializes the multisig wallet with a list of owners.
     * @dev The constructor sets the initial owners and ensures no duplicates or zero addresses.
     * @param _owners The array of addresses to be set as initial owners.
     */
    constructor(address[] memory _owners) {
        require(
            _owners.length > 0,
            "MultisigWallet: at least one owner required"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(
                owner != address(0),
                "MultisigWallet: owner address cannot be zero"
            );
            require(!isOwner[owner], "MultisigWallet: duplicate owner address");

            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    /**
     * @notice Fallback function to receive Ether.
     * @dev Emits a {Deposit} event upon receiving Ether.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @notice Submits a transaction to be confirmed by the owners.
     * @dev Depending on the transaction type, it decodes the data and emits a {SubmitTransaction} event. Once submitted the transaction gets directly confirmed for that owner by calling the confirmTransaction funcion.
     * @param _transactionType The type of the transaction.
     * @param _to The address to send the transaction to.
     * @param _value The amount of Ether to send (if applicable).
     * @param _data The data payload of the transaction.
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
     * @notice Confirms a submitted transaction.
     * @dev Increments the confirmation count and executes the transaction if enough confirmations are reached.
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
     * @notice Executes a confirmed transaction.
     * @dev Performs the actual transaction based on its type and marks it as inactive after execution. For adding or removing multisig owners, the respective internal function get called.
     * @param _txIndex The index of the transaction to execute.
     */

    function executeTransaction(
        uint256 _txIndex
    )
        public
        txExists(_txIndex)
        isActive(_txIndex)
        nonReentrant
        onlyMultisigOwner
    {
        Transaction storage transaction = transactions[_txIndex];

        uint64 numConfirmations = transaction.numConfirmations;
        TransactionType txType = transaction.transactionType;

        require(
            hasEnoughConfirmations(numConfirmations, txType),
            "MultisigWallet: insufficient confirmations to execute"
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
            require(success, "MultisigWallet: external call failed");
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
     * @notice Revokes a confirmation for a transaction.
     * @dev Decrements the confirmation count.
     * @param _txIndex The index of the transaction to revoke confirmation for.
     */

    function revokeConfirmation(
        uint256 _txIndex
    ) public onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            isConfirmed[_txIndex][msg.sender],
            "MultisigWallet: Transaction has not been confirmed"
        );

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @notice Submits a transaction to send Ether to a specified address.
     * @dev Utilizes {submitTransaction} with `TransactionType.ETH`.
     * @param _to The recipient address.
     * @param _amount The amount of Ether to send (in Wei).
     */
    function sendETH(address _to, uint256 _amount) public onlyMultisigOwner {
        require(_to != address(0), "MultisigWallet: receiver address required");
        require(_amount > 0, "MultisigWallet: Ether (Wei) amount required");
        submitTransaction(TransactionType.ETH, _to, _amount, "");
    }

    /**
     * @notice Adds a new owner to the multisig wallet.
     * @dev Submits a transaction of type `AddOwner` which requires confirmations.
     * @param _newOwner The address of the new owner to be added.
     */
    function addOwner(address _newOwner) public onlyMultisigOwner {
        require(
            _newOwner != address(0),
            "MultisigWallet: new owner address required"
        );
        require(!isOwner[_newOwner], "MultisigWallet: owner already exists");
        submitTransaction(TransactionType.AddOwner, _newOwner, 0, "");
    }

    /**
     * @notice Internal function to add a new owner after sufficient confirmations.
     * @dev Adds the new owner, updates mappings, and emits an {OwnerAdded} event.
     * @param _newOwner The address of the new owner to be added.
     * @param _txIndex The index of the transaction that triggered the addition.
     */
    function addOwnerInternal(
        address _newOwner,
        uint256 _txIndex
    ) internal onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations * 3 >= owners.length * 2,
            "MultisigWallet: insufficient confirmations to add owner"
        );

        require(
            !isOwner[_newOwner],
            "MultisigWallet: address is already an owner"
        );

        // Clear pending transactions before adding the new owner
        deactivatePendingTransactions();

        isOwner[_newOwner] = true;
        owners.push(_newOwner);

        emit OwnerAdded(_newOwner);
    }

    /**
     * @notice Removes an existing owner from the multisig wallet.
     * @dev Submits a transaction of type `RemoveOwner` which requires confirmations.
     * @param _owner The address of the owner to be removed.
     */
    function removeOwner(address _owner) public onlyMultisigOwner {
        require(
            _owner != address(0),
            "MultisigWallet: owner Address that is to be removed is required"
        );
        require(isOwner[_owner], "MultisigWallet: address is not an owner");
        submitTransaction(TransactionType.RemoveOwner, _owner, 0, "");
    }

    /**
     * @notice Internal function to remove an owner after sufficient confirmations.
     * @dev Removes the owner, updates mappings, and emits an {OwnerRemoved} event.
     * @param _owner The address of the owner to be removed.
     * @param _txIndex The index of the transaction that triggered the removal.
     */
    function removeOwnerInternal(
        address _owner,
        uint256 _txIndex
    ) internal onlyMultisigOwner txExists(_txIndex) isActive(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations * 3 >= owners.length * 2,
            "MultisigWallet: insufficient confirmations to remove owner"
        );

        require(isOwner[_owner], "MultisigWallet: address is not an owner");

        require(
            owners.length > 1,
            "MultisigWallet: cannot remove the last owner"
        );

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

    /**
     * @notice Submits a transaction to transfer ERC20 tokens.
     * @dev Encodes the ERC20 `transfer` function call and submits it as a transaction.
     * @param _token The ERC20 token contract.
     * @param _to The recipient address.
     * @param _amount The amount of tokens to transfer.
     */
    function transferERC20(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) public onlyMultisigOwner {
        require(
            address(_token) != address(0),
            "MultisigWallet: token address required"
        );
        require(_to != address(0), "MultisigWallet: receiver address required");
        require(_amount > 0, "MultisigWallet: token amount required");
        // Encode the transfer data
        bytes memory data = abi.encodeWithSelector(
            _token.transfer.selector,
            _to,
            _amount
        );
        // Submit the transaction for confirmation
        submitTransaction(TransactionType.ERC20, address(_token), 0, data);
    }

    /**
     * @notice Submits a transaction to transfer ERC20 tokens using `transferFrom`.
     * @dev Encodes the ERC20 `transferFrom` function call and submits it as a transaction.
     * @param _token The ERC20 token contract.
     * @param _from The address from which tokens will be transferred.
     * @param _to The recipient address.
     * @param _amount The amount of tokens to transfer.
     */
    function transferFromERC20(
        IERC20 _token,
        address _from,
        address _to,
        uint256 _amount
    ) public onlyMultisigOwner {
        require(
            address(_token) != address(0),
            "MultisigWallet: token address required"
        );
        require(
            _from != address(0),
            "MultisigWallet: the token-owners address is required"
        );
        require(_to != address(0), "MultisigWallet: receiver address required");
        require(_amount > 0, "MultisigWallet: token amount required");
        // Encode the transferFrom data
        bytes memory data = abi.encodeWithSelector(
            _token.transferFrom.selector,
            _from,
            _to,
            _amount
        );
        // Submit the transaction for confirmation
        submitTransaction(TransactionType.ERC20, address(_token), 0, data);
    }

    /**
     * @notice Submits a transaction to transfer an ERC721 token.
     * @dev Encodes the ERC721 `safeTransferFrom` function call and submits it as a transaction.
     * @param _token The ERC721 token contract.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The ID of the token to transfer.
     */
    function safeTransferFromERC721(
        address _token,
        address _from,
        address _to,
        uint256 _tokenId
    ) public onlyMultisigOwner {
        require(
            address(_token) != address(0),
            "MultisigWallet: token address required"
        );
        require(
            _from != address(0),
            "MultisigWallet: the tokenowners address is required"
        );
        require(_to != address(0), "MultisigWallet: receiver address required");
        // Encode the transferFrom data
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            _from,
            _to,
            _tokenId
        );
        submitTransaction(TransactionType.ERC721, _token, 0, data);
    }

    /**
     * @notice Deactivates all pending (active) transactions.
     * @dev Iterates through all transactions and marks them as inactive.
     * Emits a {PendingTransactionsDeactivated} event upon completion.
     */
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

    /**
     * @notice Allows an owner to deactivate their own pending transaction.
     * @dev Marks the specified transaction as inactive if it was submitted by the caller.
     * @param _txIndex The index of the transaction to deactivate.
     */
    function deactivateMyPendingTransaction(
        uint _txIndex
    ) public txExists(_txIndex) isActive(_txIndex) onlyMultisigOwner {
        require(
            transactions[_txIndex].owner == msg.sender,
            "MultisigWallet: only the owner can clear their submitted transaction"
        );

        // Deactivate Transaction
        transactions[_txIndex].isActive = false;

        emit DeactivatedMyPendingTransaction(_txIndex, msg.sender);
    }

    /**
     * @notice Checks if a transaction has received enough confirmations to be executed.
     * @dev The required number of confirmations varies based on the transaction type.
     * @param numConfirmations The current number of confirmations.
     * @param transactionType The type of the transaction.
     * @return True if the transaction has enough confirmations, false otherwise.
     */
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

    /**
     * @notice Decodes the transaction data based on the transaction type.
     * @dev Extracts relevant parameters from the data payload for ERC20 and ERC721 transactions.
     * @param transactionType The type of the transaction.
     * @param data The data payload of the transaction.
     * @return to The recipient address extracted from the data.
     * @return amountOrTokenId The amount of tokens or token ID extracted from the data.
     */
    function decodeTransactionData(
        TransactionType transactionType,
        bytes memory data
    ) internal pure returns (address to, uint256 amountOrTokenId) {
        if (transactionType == TransactionType.ERC20) {
            // ERC20 transfer(address recipient, uint256 amount)
            require(
                data.length == 68,
                "MultisigWallet: invalid data length for ERC20 transfer"
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
                "MultisigWallet: invalid data length for ERC721 transfer"
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
            revert(
                "MultisigWallet: unsupported transaction type for data decoding"
            );
        }
    }

    /**
     * @notice Handles the receipt of an ERC721 token.
     * @dev This function is called whenever an ERC721 `safeTransfer` is performed to this contract.
     * It must return the function selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented, the transfer will be reverted.
     * @param operator The address which called `safeTransferFrom`.
     * @param from The address which previously owned the token.
     * @param tokenId The NFT identifier which is being transferred.
     * @param data Additional data with no specified format.
     * @return bytes4 Returns `IERC721Receiver.onERC721Received.selector` to confirm the token transfer.
     */

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        emit ERC721Received(operator, from, tokenId, data);
        return this.onERC721Received.selector;
    }

    /**
     * @notice Retrieves the total number of owners.
     * @return ownerCount The number of current owners in the multisig wallet.
     */
    function getOwnerCount() public view returns (uint256) {
        uint256 ownerCount = owners.length;
        return ownerCount;
    }

    /**
     * @notice Retrieves the list of all owners.
     * @return ownersList An array containing the addresses of all current owners.
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}
