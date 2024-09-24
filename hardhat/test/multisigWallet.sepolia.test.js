// test/multisigWallet.sepolia.test.js

import { expect } from "chai";
import { ethers } from "hardhat";
import dotenv from "dotenv";
dotenv.config();

describe("MultisigWallet - Sepolia Testnet", function () {
  let multisigWallet;
  let owner1;
  let provider;

  // Environment variables
  const {
    MULTISIGWALLET_ADDRESS,
    OWNER1_ADDRESS,
    OWNER1_PRIVATE_KEY,
    SEPOLIA_RPC_URL,
  } = process.env;

  // Constants
  const DEPOSIT_AMOUNT = ethers.utils.parseEther("0.01"); // 0.01 ETH
  const RECIPIENT_ADDRESS = "0xYourRecipientAddressHere"; // Replace with a valid address
  const GAS_MARGIN = ethers.utils.parseEther("0.001"); // 0.001 ETH margin for gas discrepancies

  before(async function () {
    // Validate environment variables
    if (
      !MULTISIGWALLET_ADDRESS ||
      !OWNER1_ADDRESS ||
      !OWNER1_PRIVATE_KEY ||
      !SEPOLIA_RPC_URL
    ) {
      throw new Error(
        "Please ensure MULTISIGWALLET_ADDRESS, OWNER1_ADDRESS, OWNER1_PRIVATE_KEY, and SEPOLIA_RPC_URL are set in your .env file"
      );
    }

    // Initialize provider for Sepolia
    provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC_URL);

    // Initialize signer (owner1) using the private key
    owner1 = new ethers.Wallet(OWNER1_PRIVATE_KEY, provider);

    // Normalize and compare addresses using ethers.js
    expect(ethers.utils.getAddress(owner1.address)).to.equal(
      ethers.utils.getAddress(OWNER1_ADDRESS)
    );

    console.log(`Connected as Owner1: ${owner1.address}`);

    // Connect to the MultisigWallet contract
    multisigWallet = await ethers.getContractAt(
      "MultisigWallet",
      MULTISIGWALLET_ADDRESS,
      owner1
    );
  });

  it("Should have the correct owners", async function () {
    const owners = await multisigWallet.getOwners();
    expect(owners).to.include.members([
      ethers.utils.getAddress(owner1.address),
      // Add other owner addresses if applicable
      // e.g., ethers.utils.getAddress("0xOwner2Address"), ethers.utils.getAddress("0xOwner3Address")
    ]);
  });

  it("Should have the correct required confirmations", async function () {
    const required = await multisigWallet.required();
    expect(required).to.equal(2); // Adjust based on your contract's required confirmations
  });

  it("Should have sufficient initial balance", async function () {
    const initialWalletBalance = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );
    expect(initialWalletBalance).to.be.gte(DEPOSIT_AMOUNT);
  });

  it("Owner1 should have sufficient balance to deposit", async function () {
    const initialOwner1Balance = await provider.getBalance(owner1.address);
    expect(initialOwner1Balance).to.be.gte(DEPOSIT_AMOUNT);
  });

  it("Owner1 can submit a deposit", async function () {
    // Fetch initial balances
    const initialOwner1Balance = await provider.getBalance(owner1.address);
    const initialWalletBalance = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    // Send deposit transaction
    const depositTx = await owner1.sendTransaction({
      to: MULTISIGWALLET_ADDRESS,
      value: DEPOSIT_AMOUNT,
    });

    // Wait for deposit transaction to be mined
    const depositReceipt = await depositTx.wait();

    // Track gas cost for deposit transaction
    const gasUsedDeposit = depositReceipt.gasUsed.mul(
      depositReceipt.effectiveGasPrice
    );

    // Fetch wallet balance after deposit
    const walletBalanceAfterDeposit = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    // Assertions
    expect(walletBalanceAfterDeposit).to.equal(
      initialWalletBalance.add(DEPOSIT_AMOUNT)
    );

    // Log gas used (optional)
    console.log(
      `Gas Used for Deposit: ${ethers.utils.formatEther(gasUsedDeposit)} ETH`
    );

    // Store gas used for later assertions if needed
    this.gasUsedDeposit = gasUsedDeposit;
  });

  it("Should initiate a withdrawal and verify balances", async function () {
    // Fetch wallet balance before withdrawal
    const walletBalanceBeforeWithdrawal = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    // Initiate withdrawal transaction
    const withdrawalTx = await multisigWallet.sendETH(
      RECIPIENT_ADDRESS,
      walletBalanceBeforeWithdrawal
    );

    // Wait for withdrawal transaction to be mined
    const withdrawalReceipt = await withdrawalTx.wait();

    // Track gas cost for withdrawal transaction
    const gasUsedWithdrawal = withdrawalReceipt.gasUsed.mul(
      withdrawalReceipt.effectiveGasPrice
    );

    // Fetch final wallet balance
    const finalWalletBalance = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    // Assertions
    expect(finalWalletBalance).to.equal(0);

    // Fetch final owner1 balance
    const finalOwner1Balance = await provider.getBalance(owner1.address);

    // Calculate the expected final balance of owner1 after gas costs
    // Note: Adjust this calculation based on your contract's logic.
    // Assuming sendETH transfers funds to RECIPIENT_ADDRESS, not owner1
    // Thus, owner1's balance is primarily affected by gas costs.
    const expectedFinalBalance = await provider
      .getBalance(owner1.address)
      .add(walletBalanceBeforeWithdrawal) // If owner1 is the recipient
      .sub(this.gasUsedDeposit) // Subtract gas used in deposit
      .sub(gasUsedWithdrawal); // Subtract gas used in withdrawal

    // Calculate the difference
    const balanceDifference = finalOwner1Balance
      .sub(expectedFinalBalance)
      .abs();

    // Assertion with margin
    expect(balanceDifference).to.be.lte(GAS_MARGIN);

    // Log gas used (optional)
    console.log(
      `Gas Used for Withdrawal: ${ethers.utils.formatEther(
        gasUsedWithdrawal
      )} ETH`
    );
  });

  // Additional tests can be added here to cover more functionalities
});
