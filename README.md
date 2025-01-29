
# MultisigWallet

A Solidity-based multisig wallet that requires multiple confirmations to execute transactions. This contract uses [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) libraries under the hood.

---

## Overview

- **Contract Name:** `MultisigWallet`  
- **Compiler Version:** `0.8.7` (or higher)
- **Key Features:**
  - **Multiple confirmations** for executing transactions.
  - **Support** for ETH, ERC20, ERC721, and batch transfers.
  - Ability to **add and remove owners** through multisig transactions.
  - Deactivates pending transactions when adding or removing owners, ensuring consistent and secure state.
  - Built-in **reentrancy protection** via `ReentrancyGuard`.

---

## Repository Structure

- `contracts/MultisigWallet.sol`: The main contract source.
- `hardhat/`: Scripts/tests for **staging** on actual testnets (used because Foundry’s live network support is limited).
- `test/` or `foundry-tests/`: Local unit tests using Foundry.
- `lib/`: (If present) dependencies or library code.
- `third-party-licenses/`: Contains additional license details for third-party code, e.g., OpenZeppelin.

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
     npm install
     ```

### Deployment

- **Local / Unit Test Deployment** (Foundry):
  ```bash
  forge build
  forge test
  ```
  You can also deploy locally (Anvil) or to other networks using Foundry’s CLI.

- **Constructor**:
  ```solidity
  constructor(address[] memory _owners)
  ```
  - Pass an array of owner addresses (e.g., `[0xOwner1, 0xOwner2, 0xOwner3]`).
  - Do **not** send ETH in the constructor.

  Example command for Foundry:
  ```bash
  forge create --rpc-url <YOUR_RPC_URL> \
               --constructor-args "['0xOwner1','0xOwner2','0xOwner3']" \
               MultisigWallet
  ```

- **Staging / Testnet Deployment** (Hardhat):
  1. Go to `hardhat/`.
  2. Configure your `hardhat.config.js` or `hardhat.config.ts` (RPC settings, private key, etc.).
  3. Run:
     ```bash
     npx hardhat run scripts/deploy.ts --network <testnet-name>
     ```
  Foundry doesn’t fully support certain live operations (like Etherscan verification), so Hardhat is used.

---

## Interacting with the Contract

### Submitting a Transaction

```solidity
function submitTransaction(
  TransactionType _transactionType,
  address _to,
  uint256 _value,
  bytes memory _data
) public onlyMultisigOwner
```

- `_value` is in **Wei** when sending ETH.
- For pure ETH transfers, use `0x` as `data`.
- When you call `submitTransaction`, the transaction is created and **auto-confirmed** by the calling owner.

### Confirming / Revoking

- **Confirm**: `confirmTransaction(uint256 _txIndex)`
- **Revoke**:  `revokeConfirmation(uint256 _txIndex)`

Requires you to be an owner, and the transaction must still be active.

### Sending ETH

```solidity
function sendETH(address _to, uint256 _amount) public onlyMultisigOwner
```
- `_amount` in Wei.
- Uses `submitTransaction` internally with `TransactionType.ETH`.

### ERC20 / ERC721 Transfers

- **ERC20**: `transferERC20`, `transferFromERC20`
- **ERC721**: `safeTransferFromERC721`

All submit a transaction under the hood (with the correct function signature encoded).

### Batch Transfers

```solidity
function batchTransfer(BatchTransaction[] memory transfers)
```
- Each `BatchTransaction` has `to`, `tokenAddress`, `value`, `tokenId`.
- Supports bulk sending in a single multisig transaction.

---

## Testing

- **Unit Tests (Foundry)**:
  ```bash
  forge test
  ```
  Runs local tests on Anvil.

- **Staging Tests (Hardhat)**:
  ```bash
  cd hardhat
  npx hardhat test --network <testnet-name>
  ```
  Used to confirm behavior on real networks.

---

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

## Third-Party Libraries

This project includes code from the following open-source project(s):

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - Licensed under the MIT License.  
- Further details can be found in the [`third-party-licenses`](../third-party-licenses) folder.

---

## How to Use

1. **Deploy** the contract with an array of owners. Example:
   ```bash
   ["0x123...","0xABC...","0x987..."]
   ```
2. **Submit a Transaction**:
   - Value must be in Wei if sending ETH.
   - If sending only ETH, use `data = 0x`.
3. **Confirm**:
   - After a transaction is submitted, you (and other owners) must confirm.
   - Once enough confirmations are reached, you can execute.
4. **Be mindful**:
   - Some transactions (like adding/removing owners) require 2/3 majority.
   - Simpler transactions require over 50% approval.

If you need more information or have questions, please open an issue in this repository.