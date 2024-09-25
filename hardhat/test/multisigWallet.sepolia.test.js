// test/multisigWallet.sepolia.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
require("dotenv").config({ path: "../.env" });

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
  const DEPOSIT_AMOUNT = ethers.parseEther("0.01"); // 0.01 ETH
  const GAS_MARGIN = ethers.parseEther("0.001"); // 0.001 ETH margin for gas discrepancies

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
    provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);

    // Initialize signer (owner1) using the private key
    owner1 = new ethers.Wallet(OWNER1_PRIVATE_KEY, provider);

    // Normalize and compare addresses using ethers.js
    expect(ethers.getAddress(owner1.address)).to.equal(
      ethers.getAddress(OWNER1_ADDRESS)
    );

    // Connect to the MultisigWallet contract
    multisigWallet = await ethers.getContractAt(
      "MultisigWallet",
      MULTISIGWALLET_ADDRESS,
      owner1
    );
  });

  it("MultisigWallet can receive deposits", async function () {
    // Fetch initial balances
    const initialOwner1Balance = await provider.getBalance(owner1.address);
    const initialWalletBalance = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    //Assert that the Wallet has no ETH
    expect(initialWalletBalance).to.equal(0n);

    // Send deposit transaction
    const depositTx = await owner1.sendTransaction({
      to: MULTISIGWALLET_ADDRESS,
      value: DEPOSIT_AMOUNT,
    });

    // Wait for deposit transaction to be mined
    const depositReceipt = await depositTx.wait();

    // Track gas cost for deposit transaction
    const gasUsedDeposit = depositReceipt.gasUsed * depositReceipt.gasPrice;
    // Fetch wallet balance after deposit
    const walletBalanceAfterDeposit = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    // Assertions
    expect(walletBalanceAfterDeposit).to.equal(DEPOSIT_AMOUNT);

    // Now revert back to initial Status by getting the Eth back to Owner1

    // Initiate withdrawal transaction
    const withdrawalTx = await multisigWallet.sendETH(
      owner1.address,
      walletBalanceAfterDeposit
    );

    // Wait for withdrawal transaction to be mined
    const withdrawalReceipt = await withdrawalTx.wait();

    // Track gas cost for withdrawal transaction
    const gasUsedWithdrawal =
      withdrawalReceipt.gasUsed * withdrawalReceipt.gasPrice;

    // Fetch final wallet balance
    const finalWalletBalance = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    // Assertions
    expect(finalWalletBalance).to.equal(0n);

    // Fetch final owner1 balance
    const finalOwner1Balance = await provider.getBalance(owner1.address);

    const expectedFinalOwner1Balance =
      initialOwner1Balance - gasUsedDeposit - gasUsedWithdrawal;

    // Calculate the difference
    const balanceDifference = finalOwner1Balance - expectedFinalOwner1Balance;
    const absBalanceDifference =
      balanceDifference < 0n ? -balanceDifference : balanceDifference;

    // Assertion with margin
    expect(absBalanceDifference <= GAS_MARGIN).to.be.true;
  });

  // Additional tests can be added here to cover more functionalities
});
