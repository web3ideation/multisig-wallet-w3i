# MultisigWallet

A Solidity-based multisig wallet that requires multiple confirmations to execute transactions. This contract uses [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) libraries under the hood.

---

Deployed on the Ethereum Mainnet at `0x66dcc49c47ebc505a4b560fD14Dc143f0098407f`

---

## Overview

- **Contract Name:** `MultisigWallet`  
- **Compiler Version:** `0.8.7` (or higher)
- **Key Features:**
  - **Multiple confirmations** for executing transactions.
  - **Support** for ETH, ERC20, ERC721, Custom ("other") and batch transfers (at consensus >50%).
  - Ability to **add and remove owners** through multisig transactions (at consensus =2/3).
  - Deactivates pending transactions when adding or removing owners, ensuring consistent and secure state.
  - Built-in **reentrancy protection** via `ReentrancyGuard`.

---

## Repository Structure

- `src/MultisigWallet.sol`: The main contract source.
- `hardhat/`: Scripts/tests for **staging** on actual testnets (used because Foundry’s live network support is limited).
- `test/` or `foundry-tests/`: Local unit tests using Foundry.
- `lib/`: dependencies or library code.
- `script/`: Contains deployment scripts.

---

## Usage

### Installation

1. **Clone** the repo:
   ```bash
   git clone https://github.com/<your-user>/<your-repo>.git
   ```
2. **Install Foundry** if not already:
   - See the [Foundry Book](https://book.getfoundry.sh/getting-started/installation.html) for details.
3. **Install dependencies**:
   - If you have a `foundry.toml`, run:
     ```bash
     forge install
     ```
   - If using Hardhat for staging tests, install packages within `hardhat/`:
     ```bash
     cd hardhat
     yarn
     ```

### Deployment

- **Constructor**:
  ```solidity
  constructor(address[] memory _owners)
  ```
  - Pass an array of owner addresses (e.g., `[0xOwner1, 0xOwner2, 0xOwner3]`).
  - Do **not** send ETH in the constructor.


- **Testnet Deployment** (Foundry):
  1. Run: `source .env` to initialize dotenv.
  2. Run:
     ```bash
     forge script script/DeployMultisigWalletSepolia.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify --account <Keystore ERC-2335 account Name> --sender <Keystore ERC-2335 public key>
     ```
  Foundry doesn’t fully support certain live operations (like Etherscan verification), so Hardhat is used for staging (/hardhat/test).

---

## Interacting with the Contract

### Sending ETH

```solidity
function sendETH(address _to, uint256 _amount) public onlyMultisigOwner
```

- `_amount` is in Wei.
- Uses `submitTransaction` internally with `TransactionType.ETH`.
- Once the required confirmations are reached (>50%), the transaction gets executed (the last owner to confirm pays the gasfees to execute).

### ERC20 / ERC721 Transfers

- **ERC20**: `transferERC20`, `transferFromERC20`
- **ERC721**: `safeTransferFromERC721`

- All submit a transaction under the hood (with the correct function signature encoded).
- Once the required confirmations are reached (>50%), the transaction gets executed (the last owner to confirm pays the gasfees to execute).

### Batch Transfers

```solidity
function batchTransfer(BatchTransaction[] memory transfers)
```

- Each `BatchTransaction` has `to`, `tokenAddress`, `value`, `tokenId`.
- Supports bulk sending in a single multisig transaction.
- Test a large BatchTransfer on a local testnet first to check if the gas costs are within EVM constraints.
- Once the required confirmations are reached (>50%), the transaction gets executed (the last owner to confirm pays the gasfees to execute).

### Adding/Removing Owners

```solidity
function addOwner(address _newOwner) public onlyMultisigOwner
function removeOwner(address _owner) public onlyMultisigOwner
```

- Both functions are wrappers around `submitTransaction` with `TransactionType.AddOwner` or `TransactionType.RemoveOwner`.
- Internally, these proposals **require 2/3 majority confirmations** to succeed, as adding or removing owners is a critical action.
- Once the required confirmations are reached, the transaction gets executed, which will update the owners array and deactivate all pending transactions to maintain a secure state (the last owner to confirm pays the gasfees to execute).

### Submitting a custom ("other") Transaction

```solidity
function submitTransaction(
  TransactionType _transactionType,
  address _to,
  uint256 _value,
  bytes memory _data
) public onlyMultisigOwner
```

- `_value` is in **Wei** when sending ETH.
- To call a function on **another contract** (an "Other" transaction), encode its function signature and arguments.
  - For example, in Foundry: `cast calldata "setName(string)" "Wolfgang"`.
  - Then call `submitTransaction` with `_transactionType = 6 (Other)`, `_to = <target contract>`, `_value = 0`, and `_data = <encoded data>`.
- When you call `submitTransaction`, the transaction is created and **auto-confirmed** by the calling owner.
- Once the required confirmations are reached (>50%), the transaction gets executed (the last owner to confirm pays the gasfees to execute).

### Confirming / Revoking

```solidity
function confirmTransaction(uint256 _txIndex)
function revokeConfirmation(uint256 _txIndex)
```

- Any multisig owner can confirm a transaction.
- The transaction must still be active.
- Once enough confirmations are reached (based on the transaction type), executeTransaction gets triggered automatically (gascosts for the transaction will be paid by the last confirmer).

---

## Testing

- **Unit Tests (Foundry)**:
   ```bash
  forge test --match-contract MultisigWalletTest -vvv
  ```
  Runs local tests on Anvil.

- **Staging Tests (Hardhat)**:
  Used to confirm behavior on real networks.

  update dotenv values for deployment addresses

  ```bash
  cd hardhat
  yarn hardhat test multisigWallet.sepolia.test.js --network seploia
  ```
  
  Change the "tokenId"s and "bigIntTokenId" before every run!

---

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

## Third-Party Libraries

This project includes code from the following open-source project(s):

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - Licensed under the MIT License.  
- Further details can be found in the [`third-party-licenses`](../third-party-licenses) folder.
