// test/multisigWallet.sepolia.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
require("dotenv").config({ path: "../.env" });

describe("MultisigWallet - Sepolia Testnet", function () {
  let multisigWallet;
  let owner1;
  let owner2;
  let owner3;
  let owner4;
  let owner5;
  let provider;

  // Environment variables
  const {
    MULTISIGWALLET_ADDRESS,
    OWNER1_ADDRESS,
    OWNER1_PRIVATE_KEY,
    OWNER2_ADDRESS,
    OWNER2_PRIVATE_KEY,
    OWNER3_ADDRESS,
    OWNER3_PRIVATE_KEY,
    OWNER4_ADDRESS,
    OWNER4_PRIVATE_KEY,
    OWNER5_ADDRESS,
    OWNER5_PRIVATE_KEY,
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

    // Initialize signers using the private key
    owner1 = new ethers.Wallet(OWNER1_PRIVATE_KEY, provider);
    owner2 = new ethers.Wallet(OWNER2_PRIVATE_KEY, provider);
    owner3 = new ethers.Wallet(OWNER3_PRIVATE_KEY, provider);
    owner4 = new ethers.Wallet(OWNER4_PRIVATE_KEY, provider);
    owner5 = new ethers.Wallet(OWNER5_PRIVATE_KEY, provider);

    // Normalize and compare addresses using ethers.js
    expect(ethers.getAddress(owner1.address)).to.equal(
      ethers.getAddress(OWNER1_ADDRESS)
    );
    expect(ethers.getAddress(owner2.address)).to.equal(
      ethers.getAddress(OWNER2_ADDRESS)
    );
    expect(ethers.getAddress(owner3.address)).to.equal(
      ethers.getAddress(OWNER3_ADDRESS)
    );
    expect(ethers.getAddress(owner4.address)).to.equal(
      ethers.getAddress(OWNER4_ADDRESS)
    );
    expect(ethers.getAddress(owner5.address)).to.equal(
      ethers.getAddress(OWNER5_ADDRESS)
    );

    // Connect owner1 to the MultisigWallet contract
    multisigWallet = await ethers.getContractAt(
      "MultisigWallet",
      MULTISIGWALLET_ADDRESS,
      owner1
    );
  });

  it("MultisigWallet can receive deposits and withdraw with only one owner", async function () {
    // Fetch initial balances
    const initialOwner1Balance = await provider.getBalance(owner1.address);
    const initialWalletBalance = await provider.getBalance(
      MULTISIGWALLET_ADDRESS
    );

    console.log("initialWalletBalance is: ", initialWalletBalance);

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

    // Assert that the ETH arrived
    expect(walletBalanceAfterDeposit).to.equal(
      initialWalletBalance + DEPOSIT_AMOUNT
    );

    // check deposit event logs

    const depositBlock = depositReceipt.blockNumber;

    // Filter for reveived events in the receipt
    const depositEvents = await multisigWallet.queryFilter(
      "Deposit",
      depositBlock,
      depositBlock
    );

    // Ensure that  one SubmitTransaction event was emitted
    expect(depositEvents.length).to.equal(1);

    // Extract txIndex from the event arguments
    const depositEvent = depositEvents[0];

    // Assert that the Event is emitted as expected
    expect(depositEvent.args.sender).to.equal(owner1.address);
    expect(depositEvent.args.amountOrTokenId).to.equal(DEPOSIT_AMOUNT);
    expect(depositEvent.args.balance).to.equal(
      initialWalletBalance + DEPOSIT_AMOUNT
    );

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

    // check Submit event logs

    const withdrawalBlock = withdrawalReceipt.blockNumber;

    // Filter for reveived events in the receipt
    const submitTxEvents = await multisigWallet.queryFilter(
      "SubmitTransaction",
      withdrawalBlock,
      withdrawalBlock
    );

    // Ensure that  one SubmitTransaction event was emitted
    expect(submitTxEvents.length).to.equal(1);

    // Extract txIndex from the event arguments
    const submitTxEvent = submitTxEvents[0];

    // Assert that the Event is emitted as expected
    expect(submitTxEvent.args._transactionType).to.equal(0n);
    expect(submitTxEvent.args.to).to.equal(owner1.address);
    expect(submitTxEvent.args.value).to.equal(walletBalanceAfterDeposit);
    expect(submitTxEvent.args.tokenAddress).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(submitTxEvent.args.amountOrTokenId).to.equal(0n);
    expect(submitTxEvent.args.owner).to.equal(owner1.address);
    expect(submitTxEvent.args.data).to.equal("0x");

    // check confirm event logs

    // Filter for reveived events in the receipt
    const confirmTxEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      withdrawalBlock,
      withdrawalBlock
    );

    // Ensure that  one SubmitTransaction event was emitted
    expect(confirmTxEvents.length).to.equal(1);

    // Extract txIndex from the event arguments
    const confirmTxEvent = confirmTxEvents[0];

    // Assert that the Event is emitted as expected
    expect(confirmTxEvent.args.owner).to.equal(owner1.address);
    expect(confirmTxEvent.args.txIndex).to.equal(submitTxEvent.args.txIndex);

    // check execute event logs

    // Filter for reveived events in the receipt
    const executeTxEvents = await multisigWallet.queryFilter(
      "ExecuteTransaction",
      withdrawalBlock,
      withdrawalBlock
    );

    // Ensure that  one SubmitTransaction event was emitted
    expect(executeTxEvents.length).to.equal(1);

    // Extract txIndex from the event arguments
    const executeTxEvent = executeTxEvents[0];

    // Assert that the Event is emitted as expected
    expect(executeTxEvent.args._transactionType).to.equal(0n);
    expect(executeTxEvent.args.txIndex).to.equal(submitTxEvent.args.txIndex);
    expect(executeTxEvent.args.to).to.equal(owner1.address);
    expect(executeTxEvent.args.value).to.equal(walletBalanceAfterDeposit);
    expect(executeTxEvent.args.tokenAddress).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(executeTxEvent.args.amountOrTokenId).to.equal(0n);
    expect(executeTxEvent.args.owner).to.equal(owner1.address);
    expect(executeTxEvent.args.data).to.equal("0x");
  });

  // it("MultisigWallet can add and delete 4 Owners (total 5)", async function () {
  //   // Fetch initial Owners
  //   const initialOwners = await multisigWallet.getOwners();

  //   //Assert that Owner1 is the only Owner
  //   expect(initialOwners).to.equal([owner1.address]);

  //   // Send addOwner2 transaction
  //   const addOwner2Tx = await multisigWallet.addOwner(owner2.address);

  //   // Wait for addOwner2 transaction to be mined
  //   const addOwner2Receipt = await addOwner2Tx.wait();

  //   // check the event logs

  //   // Fetch Owners
  //   const twoOwners = await multisigWallet.getOwners();

  //   //Assert that owner1 and owner2 are the Owners
  //   expect(twoOwners).to.equal([owner1.address, owner2.address]);
  //   //
  //   //
  //   //
  //   //
  //   //
  //   //

  //   // add the third owner

  //   //
  //   //

  //   //get the transaction index from the event logs

  //   // Filter for SubmitTransaction events in the receipt
  //   const submitTxEvents = addOwner2or3or4or5Receipt.events.filter(
  //     (event) => event.event === "SubmitTransaction"
  //   );

  //   // Ensure that  one SubmitTransaction event was emitted
  //   expect(submitTxEvents.length).to.equal(1);

  //   // Extract txIndex from the event arguments
  //   const submitTxEvent = submitTxEvents[0];
  //   const txIndex = submitTxEvent.args.txIndex;

  //   // Assert that the transaction is the correct ETH transfer
  //   expect(submitTxEvent.args._transactionType).to.equal(3);
  //   expect(submitTxEvent.args.to).to.equal(owner2.address);
  //   expect(submitTxEvent.args.value).to.equal(0);
  //   expect(submitTxEvent.args.tokenAddress).to.equal(
  //     "0x0000000000000000000000000000000000000000"
  //   );
  //   expect(submitTxEvent.args.amountOrTokenId).to.equal(0);
  //   expect(submitTxEvent.args.owner).to.equal(owner1.address);
  //   expect(submitTxEvent.args.data).to.equal("0x");

  //   // Connect onwer2 to the MultisigWallet contract
  //   multisigWallet.connect(owner2);

  //   // let owner2 confirm that addOnwer3 transcation
  //   const owner2ConfirmTx = await multisigWallet.confirm(txIndex);

  //   // Wait for deposit transaction to be mined
  //   const Owner2confirmReceipt = await owner2ConfirmTx.wait();
  //   //
  //   //
  //   //

  //   // Fetch Owners
  //   const threeOwners = await multisigWallet.getOwners();

  //   //Assert that owner1 and owner2 are the Owners
  //   expect(initialOwners).to.equal([owner1.address, owner2.address]);

  //   // Now revert back to initial Status by getting the Eth back to Owner1

  //   // Initiate withdrawal transaction
  //   const withdrawalTx = await multisigWallet.sendETH(
  //     owner1.address,
  //     walletBalanceAfterDeposit
  //   );

  //   // Wait for withdrawal transaction to be mined
  //   const withdrawalReceipt = await withdrawalTx.wait();

  //   // Track gas cost for withdrawal transaction
  //   const gasUsedWithdrawal =
  //     withdrawalReceipt.gasUsed * withdrawalReceipt.gasPrice;

  //   // Fetch final wallet balance
  //   const finalWalletBalance = await provider.getBalance(
  //     MULTISIGWALLET_ADDRESS
  //   );

  //   // Assertions
  //   expect(finalWalletBalance).to.equal(0n);

  //   // Fetch final owner1 balance
  //   const finalOwner1Balance = await provider.getBalance(owner1.address);

  //   const expectedFinalOwner1Balance =
  //     initialOwner1Balance - gasUsedDeposit - gasUsedWithdrawal;

  //   // Calculate the difference
  //   const balanceDifference = finalOwner1Balance - expectedFinalOwner1Balance;
  //   const absBalanceDifference =
  //     balanceDifference < 0n ? -balanceDifference : balanceDifference;

  //   // Assertion with margin
  //   expect(absBalanceDifference <= GAS_MARGIN).to.be.true;
  // });
});
