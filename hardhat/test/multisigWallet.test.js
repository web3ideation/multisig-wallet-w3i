// test/multisigWallet.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
require("dotenv").config({ path: "../.env" });

describe("MultisigWallet", function () {
  let multisigWallet;
  let owner1;
  let owner2;
  let owner3;
  let owner4;
  let owner5;
  //// let provider;

  //// // Environment variables
  //// const {
  ////   MULTISIGWALLET_ADDRESS,
  ////   OWNER1_ADDRESS,
  ////   OWNER1_PRIVATE_KEY,
  ////   OWNER2_ADDRESS,
  ////   OWNER2_PRIVATE_KEY,
  ////   OWNER3_ADDRESS,
  ////   OWNER3_PRIVATE_KEY,
  ////   OWNER4_ADDRESS,
  ////   OWNER4_PRIVATE_KEY,
  ////   OWNER5_ADDRESS,
  ////   OWNER5_PRIVATE_KEY,
  ////   SEPOLIA_RPC_URL,
  //// } = process.env;

  // Constants
  const DEPOSIT_AMOUNT = ethers.parseEther("0.01"); // 0.01 ETH
  const GAS_MARGIN = ethers.parseEther("0.001"); // 0.001 ETH margin for gas discrepancies

  before(async function () {
    //// // Validate environment variables
    //// if (
    ////   !MULTISIGWALLET_ADDRESS ||
    ////   !OWNER1_ADDRESS ||
    ////   !OWNER1_PRIVATE_KEY ||
    ////   !SEPOLIA_RPC_URL
    //// ) {
    ////   throw new Error(
    ////     "Please ensure MULTISIGWALLET_ADDRESS, OWNER1_ADDRESS, OWNER1_PRIVATE_KEY, and SEPOLIA_RPC_URL are set in your .env file"
    ////   );
    //// }

    //// // Initialize provider for Sepolia
    //// provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);

    //// // Initialize signers using the private key
    //// owner1 = new ethers.Wallet(OWNER1_PRIVATE_KEY, provider);
    //// owner2 = new ethers.Wallet(OWNER2_PRIVATE_KEY, provider);
    //// owner3 = new ethers.Wallet(OWNER3_PRIVATE_KEY, provider);
    //// owner4 = new ethers.Wallet(OWNER4_PRIVATE_KEY, provider);
    //// owner5 = new ethers.Wallet(OWNER5_PRIVATE_KEY, provider);

    //// // Normalize and compare addresses using ethers.js
    //// expect(ethers.getAddress(owner1.address)).to.equal(
    ////   ethers.getAddress(OWNER1_ADDRESS)
    //// );
    //// expect(ethers.getAddress(owner2.address)).to.equal(
    ////   ethers.getAddress(OWNER2_ADDRESS)
    //// );
    //// expect(ethers.getAddress(owner3.address)).to.equal(
    ////   ethers.getAddress(OWNER3_ADDRESS)
    //// );
    //// expect(ethers.getAddress(owner4.address)).to.equal(
    ////   ethers.getAddress(OWNER4_ADDRESS)
    //// );
    //// expect(ethers.getAddress(owner5.address)).to.equal(
    ////   ethers.getAddress(OWNER5_ADDRESS)
    //// );

    //// // Connect owner1 to the MultisigWallet contract
    //// multisigWallet = await ethers.getContractAt(
    ////   "MultisigWallet",
    ////   MULTISIGWALLET_ADDRESS,
    ////   owner1
    //// );

    //// delete this Local environment
    // Fetch signers
    [owner1, owner2, owner3, owner4, owner5] = await ethers.getSigners();

    // Log the signers for debugging
    console.log("Deploying contracts with the following owners:");
    console.log("Owner1:", owner1.address);
    console.log("Owner2:", owner2.address);
    console.log("Owner3:", owner3.address);
    console.log("Owner4:", owner4.address);
    console.log("Owner5:", owner5.address);

    // Deploy the contract
    const MultisigWalletFactory = await ethers.getContractFactory(
      "MultisigWallet"
    );
    multisigWallet = await MultisigWalletFactory.deploy([owner1.address]);

    // Verify that the contract address is defined
    expect(multisigWallet.target).to.properAddress;
  });

  it("MultisigWallet can receive deposits and withdraw with only one owner", async function () {
    // Fetch initial balances
    const initialOwner1Balance = await ethers.provider.getBalance(
      owner1.address
    ); //// replace ethers.provider with provide
    const initialWalletBalance = await ethers.provider.getBalance(
      //// replace ethers.provider with provide
      multisigWallet.target
    );

    // Send deposit transaction
    const depositTx = await owner1.sendTransaction({
      to: multisigWallet.target,
      value: DEPOSIT_AMOUNT,
    });

    // Wait for deposit transaction to be mined
    const depositReceipt = await depositTx.wait();

    // Track gas cost for deposit transaction
    const gasUsedDeposit = depositReceipt.gasUsed * depositReceipt.gasPrice;

    // Fetch wallet balance after deposit
    const walletBalanceAfterDeposit = await ethers.provider.getBalance(
      //// replace ethers.provider with provide
      multisigWallet.target
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

    const depositEvent = depositEvents[0];

    // Assert that the Event is emitted as expected
    expect(depositEvent.args.sender).to.equal(owner1.address);
    expect(depositEvent.args.amountOrTokenId).to.equal(DEPOSIT_AMOUNT);
    expect(depositEvent.args.balance).to.equal(
      initialWalletBalance + DEPOSIT_AMOUNT
    );

    // Now revert back to initial Status by getting the Eth back to Owner1

    multisigWallet = multisigWallet.connect(owner1);

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
    const finalWalletBalance = await ethers.provider.getBalance(
      //// replace ethers.provider with provide
      multisigWallet.target
    );

    // Assertions
    expect(finalWalletBalance).to.equal(0n);

    // Fetch final owner1 balance
    const finalOwner1Balance = await ethers.provider.getBalance(owner1.address); //// replace ethers.provider with provide

    const expectedFinalOwner1Balance =
      initialOwner1Balance - gasUsedDeposit - gasUsedWithdrawal;

    // Calculate the difference
    const balanceDifference = finalOwner1Balance - expectedFinalOwner1Balance;
    const absBalanceDifference =
      balanceDifference < 0n ? -balanceDifference : balanceDifference;

    console.log("finalOwner1Balance: ", finalOwner1Balance);
    console.log("expectedFinalOwner1Balance: ", expectedFinalOwner1Balance);
    console.log("balanceDifference: ", balanceDifference);
    console.log("absBalanceDifference: ", absBalanceDifference);
    console.log("GAS_MARGIN: ", GAS_MARGIN);

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

  it("can add Owner2", async function () {
    multisigWallet = multisigWallet.connect(owner1);
    // Fetch initial Owners
    const initialOwners = await multisigWallet.getOwners();
    const ownerCount = await multisigWallet.getOwnerCount();

    //Assert that Owner1 is the only Owner
    expect(initialOwners).to.eql([owner1.address]);
    expect(ownerCount).to.eql(1n);

    // Send addOwner2 transaction
    const addOwner2Tx = await multisigWallet.addOwner(owner2.address);

    // Wait for addOwner2 transaction to be mined
    const addOwner2Receipt = await addOwner2Tx.wait();

    // Fetch Owners
    const twoOwners = await multisigWallet.getOwners();
    const twoOwnerCount = await multisigWallet.getOwnerCount();

    //Assert that owner1 and owner2 are the Owners
    expect(twoOwners).to.eql([owner1.address, owner2.address]);
    expect(twoOwnerCount).to.eql(2n);
  }),
    it("can add Owner3", async function () {
      multisigWallet = multisigWallet.connect(owner1);

      // Send addOwner3 transaction
      const addOwner3Tx = await multisigWallet.addOwner(owner3.address);

      // Wait for addOwner2 transaction to be mined
      const addOwner3Receipt = await addOwner3Tx.wait();

      // check Submit event logs

      const addOnwer3Block = addOwner3Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const submitAddOwner3TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        addOnwer3Block,
        addOnwer3Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitAddOwner3TxEvents.length).to.equal(1);

      const submitAddOwner3TxEvent = submitAddOwner3TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(submitAddOwner3TxEvent.args._transactionType).to.equal(3n);
      expect(submitAddOwner3TxEvent.args.to).to.equal(owner3.address);
      expect(submitAddOwner3TxEvent.args.value).to.equal(0n);
      expect(submitAddOwner3TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(submitAddOwner3TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(submitAddOwner3TxEvent.args.owner).to.equal(owner1.address);
      expect(submitAddOwner3TxEvent.args.data).to.equal("0x");

      // Extract txIndex from the event arguments
      const addOwner3TxIndex = submitAddOwner3TxEvent.args.txIndex;

      // owner2 confirms addOwner3

      // Connect onwer2 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner2);

      // confirm transaction
      const owner2ConfirmAddOwner3Tx = await multisigWallet.confirmTransaction(
        addOwner3TxIndex
      );

      // Wait for deposit transaction to be mined
      const Owner2confirmAddOwner3Receipt =
        await owner2ConfirmAddOwner3Tx.wait();

      // Fetch Owners
      const threeOwners = await multisigWallet.getOwners();
      const threeOwnerCount = await multisigWallet.getOwnerCount();

      //Assert that owner1, owner2 and owner 3 are the Owners
      expect(threeOwners).to.eql([
        owner1.address,
        owner2.address,
        owner3.address,
      ]);
      expect(threeOwnerCount).to.eql(3n);
    }),
    it("can add Owner4", async function () {
      multisigWallet = multisigWallet.connect(owner2);

      // Send addOwner4 transaction (this time initiated by owner2)
      const addOwner4Tx = await multisigWallet.addOwner(owner4.address);

      // Wait for addOwner2 transaction to be mined
      const addOwner4Receipt = await addOwner4Tx.wait();

      // check Submit event logs

      const addOnwer4Block = addOwner4Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const submitAddOwner4TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        addOnwer4Block,
        addOnwer4Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitAddOwner4TxEvents.length).to.equal(1);

      const submitAddOwner4TxEvent = submitAddOwner4TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(submitAddOwner4TxEvent.args._transactionType).to.equal(3n);
      expect(submitAddOwner4TxEvent.args.to).to.equal(owner4.address);
      expect(submitAddOwner4TxEvent.args.value).to.equal(0n);
      expect(submitAddOwner4TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(submitAddOwner4TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(submitAddOwner4TxEvent.args.owner).to.equal(owner2.address);
      expect(submitAddOwner4TxEvent.args.data).to.equal("0x");

      // Extract txIndex from the event arguments
      const addOwner4TxIndex = submitAddOwner4TxEvent.args.txIndex;

      // owner1 confirms addOwner4

      // Connect onwer2 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner1);

      // confirm transaction
      const owner1ConfirmAddOwner4Tx = await multisigWallet.confirmTransaction(
        addOwner4TxIndex
      );

      // Wait for deposit transaction to be mined
      const Owner1confirmAddOwner4Receipt =
        await owner1ConfirmAddOwner4Tx.wait();

      // Fetch Owners
      const fourOwners = await multisigWallet.getOwners();
      const fourOwnerCount = await multisigWallet.getOwnerCount();

      //Assert that owner1, owner2 and owner 3 are the Owners
      expect(fourOwners).to.eql([
        owner1.address,
        owner2.address,
        owner3.address,
        owner4.address,
      ]);
      expect(fourOwnerCount).to.eql(4n);
    }),
    it("can add Owner5", async function () {
      // Connect onwer2 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner4);

      // Send addOwner5 transaction (this time initiated by owner4)
      const addOwner5Tx = await multisigWallet.addOwner(owner5.address);

      // Wait for addOwner2 transaction to be mined
      const addOwner5Receipt = await addOwner5Tx.wait();

      // get the transaction index from the event logs and check Submit event logs

      const addOnwer5Block = addOwner5Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const submitAddOwner5TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        addOnwer5Block,
        addOnwer5Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitAddOwner5TxEvents.length).to.equal(1);

      const submitAddOwner5TxEvent = submitAddOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(submitAddOwner5TxEvent.args._transactionType).to.equal(3n);
      expect(submitAddOwner5TxEvent.args.to).to.equal(owner5.address);
      expect(submitAddOwner5TxEvent.args.value).to.equal(0n);
      expect(submitAddOwner5TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(submitAddOwner5TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(submitAddOwner5TxEvent.args.owner).to.equal(owner4.address);
      expect(submitAddOwner5TxEvent.args.data).to.equal("0x");

      // Extract txIndex from the event arguments
      const addOwner5TxIndex = submitAddOwner5TxEvent.args.txIndex;

      // owner3 confirms addOwner5

      // Connect onwer3 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner3);

      // confirm transaction
      const owner3ConfirmAddOwner5Tx = await multisigWallet.confirmTransaction(
        addOwner5TxIndex
      );

      // Wait for deposit transaction to be mined
      const owner3ConfirmAddOwner5Receipt =
        await owner3ConfirmAddOwner5Tx.wait();

      // check confirm event logs

      const owner3ConfirmAddOwner5Block =
        owner3ConfirmAddOwner5Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const owner3ConfirmOwner5TxEvents = await multisigWallet.queryFilter(
        "ConfirmTransaction",
        owner3ConfirmAddOwner5Block,
        owner3ConfirmAddOwner5Block
      );

      // Ensure that one SubmitTransaction event was emitted
      expect(owner3ConfirmOwner5TxEvents.length).to.equal(1);

      const owner3ConfirmOwner5TxEvent = owner3ConfirmOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner3ConfirmOwner5TxEvent.args.owner).to.equal(owner3.address);
      expect(owner3ConfirmOwner5TxEvent.args.txIndex).to.equal(
        addOwner5TxIndex
      );

      // owner1 confirms addOwner5

      // Connect onwer1 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner1);

      // confirm transaction
      const owner1ConfirmAddOwner5Tx = await multisigWallet.confirmTransaction(
        addOwner5TxIndex
      );

      // Wait for deposit transaction to be mined
      const owner1ConfirmAddOwner5Receipt =
        await owner1ConfirmAddOwner5Tx.wait();

      // Fetch Owners
      const fiveOwners = await multisigWallet.getOwners();
      const fiveOwnerCount = await multisigWallet.getOwnerCount();

      // Assert that owner1, owner2 and owner 3 are the Owners
      expect(fiveOwners).to.eql([
        owner1.address,
        owner2.address,
        owner3.address,
        owner4.address,
        owner5.address,
      ]);
      expect(fiveOwnerCount).to.eql(5n);

      // check confirm event logs

      const owner1ConfirmAddOwner5Block =
        owner1ConfirmAddOwner5Receipt.blockNumber;

      // Filter for confirm events in the receipt
      const owner1ConfirmAddOwner5TxEvents = await multisigWallet.queryFilter(
        "ConfirmTransaction",
        owner1ConfirmAddOwner5Block,
        owner1ConfirmAddOwner5Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(owner1ConfirmAddOwner5TxEvents.length).to.equal(1);

      const owner1ConfirmAddOwner5TxEvent = owner1ConfirmAddOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner1ConfirmAddOwner5TxEvent.args.owner).to.equal(owner1.address);
      expect(owner1ConfirmAddOwner5TxEvent.args.txIndex).to.equal(
        addOwner5TxIndex
      );

      // check execute event logs

      // Filter for execute events in the receipt
      const executeAddOwner5TxEvents = await multisigWallet.queryFilter(
        "ExecuteTransaction",
        owner1ConfirmAddOwner5Block,
        owner1ConfirmAddOwner5Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(executeAddOwner5TxEvents.length).to.equal(1);

      const executeAddOwner5TxEvent = executeAddOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(executeAddOwner5TxEvent.args._transactionType).to.equal(3n);
      expect(executeAddOwner5TxEvent.args.txIndex).to.equal(addOwner5TxIndex);
      expect(executeAddOwner5TxEvent.args.to).to.equal(owner5.address);
      expect(executeAddOwner5TxEvent.args.value).to.equal(0n);
      expect(executeAddOwner5TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(executeAddOwner5TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(executeAddOwner5TxEvent.args.owner).to.equal(owner1.address);
      expect(executeAddOwner5TxEvent.args.data).to.equal("0x");

      // Filter for OwnerAdded events in the receipt
      const owner5AddedTxEvents = await multisigWallet.queryFilter(
        "OwnerAdded",
        owner1ConfirmAddOwner5Block,
        owner1ConfirmAddOwner5Block
      );

      // Ensure that one OwnerAdded event was emitted
      expect(owner5AddedTxEvents.length).to.equal(1);

      const owner5AddedTxEvent = owner5AddedTxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner5AddedTxEvent.args.owner).to.equal(owner5.address);
    }),
    //
    // Now revert back to initial Status by removing all owners except Owner1

    it("can remove Owner5", async function () {
      // Connect onwer5 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner5);

      // Send removeOwner5 transaction (initiated by owner5)
      const removeOwner5Tx = await multisigWallet.removeOwner(owner5.address);

      // Wait for removeOwner5 transaction to be mined
      const removeOwner5Receipt = await removeOwner5Tx.wait();

      // get the transaction index from the event logs and check Submit event logs

      const removeOnwer5Block = removeOwner5Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const submitRemoveOwner5TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        removeOnwer5Block,
        removeOnwer5Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitRemoveOwner5TxEvents.length).to.equal(1);

      const submitRemoveOwner5TxEvent = submitRemoveOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(submitRemoveOwner5TxEvent.args._transactionType).to.equal(4n);
      expect(submitRemoveOwner5TxEvent.args.to).to.equal(owner5.address);
      expect(submitRemoveOwner5TxEvent.args.value).to.equal(0n);
      expect(submitRemoveOwner5TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(submitRemoveOwner5TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(submitRemoveOwner5TxEvent.args.owner).to.equal(owner5.address);
      expect(submitRemoveOwner5TxEvent.args.data).to.equal("0x");

      // Extract txIndex from the event arguments
      const removeOwner5TxIndex = submitRemoveOwner5TxEvent.args.txIndex;

      // owner4 confirms removeOwner5

      // Connect onwer4 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner4);

      // confirm transaction
      const owner4ConfirmRemoveOwner5Tx =
        await multisigWallet.confirmTransaction(removeOwner5TxIndex);

      // Wait for confirm transaction to be mined
      const owner4ConfirmRemoveOwner5Receipt =
        await owner4ConfirmRemoveOwner5Tx.wait();

      // check confirm event logs

      const owner4ConfirmRemoveOwner5Block =
        owner4ConfirmRemoveOwner5Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const owner4ConfirmRemoveOwner5TxEvents =
        await multisigWallet.queryFilter(
          "ConfirmTransaction",
          owner4ConfirmRemoveOwner5Block,
          owner4ConfirmRemoveOwner5Block
        );

      // Ensure that one SubmitTransaction event was emitted
      expect(owner4ConfirmRemoveOwner5TxEvents.length).to.equal(1);

      const owner4ConfirmRemoveOwner5TxEvent =
        owner4ConfirmRemoveOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner4ConfirmRemoveOwner5TxEvent.args.owner).to.equal(
        owner4.address
      );
      expect(owner4ConfirmRemoveOwner5TxEvent.args.txIndex).to.equal(
        removeOwner5TxIndex
      );

      // owner1 confirms removeOwner5

      // Connect onwer1 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner1);

      // confirm transaction
      const owner1ConfirmRemoveOwner5Tx =
        await multisigWallet.confirmTransaction(removeOwner5TxIndex);

      // Wait for confirm transaction to be mined
      const owner1ConfirmRemoveOwner5Receipt =
        await owner1ConfirmRemoveOwner5Tx.wait();

      // check confirm event logs

      const owner1ConfirmRemoveOwner5Block =
        owner1ConfirmRemoveOwner5Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const owner1ConfirmRemoveOwner5TxEvents =
        await multisigWallet.queryFilter(
          "ConfirmTransaction",
          owner1ConfirmRemoveOwner5Block,
          owner1ConfirmRemoveOwner5Block
        );

      // Ensure that one SubmitTransaction event was emitted
      expect(owner1ConfirmRemoveOwner5TxEvents.length).to.equal(1);

      const owner1ConfirmRemoveOwner5TxEvent =
        owner1ConfirmRemoveOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner1ConfirmRemoveOwner5TxEvent.args.owner).to.equal(
        owner1.address
      );
      expect(owner1ConfirmRemoveOwner5TxEvent.args.txIndex).to.equal(
        removeOwner5TxIndex
      );

      // owner2 confirms removeOwner5

      // Connect onwer3 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner2);

      // confirm transaction
      const owner2ConfirmRemoveOwner5Tx =
        await multisigWallet.confirmTransaction(removeOwner5TxIndex);

      // Wait for confirm transaction to be mined
      const owner2ConfirmRemoveOwner5Receipt =
        await owner2ConfirmRemoveOwner5Tx.wait();

      // check confirm event logs

      const owner2ConfirmRemoveOwner5Block =
        owner2ConfirmRemoveOwner5Receipt.blockNumber;

      // Filter for confirm events in the receipt
      const owner2ConfirmRemoveOwner5TxEvents =
        await multisigWallet.queryFilter(
          "ConfirmTransaction",
          owner2ConfirmRemoveOwner5Block,
          owner2ConfirmRemoveOwner5Block
        );

      // Ensure that one SubmitTransaction event was emitted
      expect(owner2ConfirmRemoveOwner5TxEvents.length).to.equal(1);

      const owner2ConfirmRemoveOwner5TxEvent =
        owner2ConfirmRemoveOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner2ConfirmRemoveOwner5TxEvent.args.owner).to.equal(
        owner2.address
      );
      expect(owner2ConfirmRemoveOwner5TxEvent.args.txIndex).to.equal(
        removeOwner5TxIndex
      );

      // Fetch Owners
      const _fourOwners = await multisigWallet.getOwners();
      const fourOwnerCount = await multisigWallet.getOwnerCount();

      // Assert that owner1, owner2, owner3 and owner4 are the Owners
      expect(_fourOwners).to.eql([
        owner1.address,
        owner2.address,
        owner3.address,
        owner4.address,
      ]);
      expect(fourOwnerCount).to.eql(4n);

      // check execute event logs

      // Filter for execute events in the receipt
      const executeRemoveOwner5TxEvents = await multisigWallet.queryFilter(
        "ExecuteTransaction",
        owner2ConfirmRemoveOwner5Block,
        owner2ConfirmRemoveOwner5Block
      );

      // Ensure that one ExecuteTransaction event was emitted
      expect(executeRemoveOwner5TxEvents.length).to.equal(1);

      const executeRemoveOwner5TxEvent = executeRemoveOwner5TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(executeRemoveOwner5TxEvent.args._transactionType).to.equal(4n);
      expect(executeRemoveOwner5TxEvent.args.txIndex).to.equal(
        removeOwner5TxIndex
      );
      expect(executeRemoveOwner5TxEvent.args.to).to.equal(owner5.address);
      expect(executeRemoveOwner5TxEvent.args.value).to.equal(0n);
      expect(executeRemoveOwner5TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(executeRemoveOwner5TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(executeRemoveOwner5TxEvent.args.owner).to.equal(owner2.address);
      expect(executeRemoveOwner5TxEvent.args.data).to.equal("0x");

      // Filter for OwnerRemoved events in the receipt
      const owner5RemovedTxEvents = await multisigWallet.queryFilter(
        "OwnerRemoved",
        owner2ConfirmRemoveOwner5Block,
        owner2ConfirmRemoveOwner5Block
      );

      // Ensure that one OwnerRemoved event was emitted
      expect(owner5RemovedTxEvents.length).to.equal(1);

      const owner5RemovedTxEvent = owner5RemovedTxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner5RemovedTxEvent.args.owner).to.equal(owner5.address);
    }),
    it("can remove Owner4", async function () {
      // Connect onwer1 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner1);

      // Send removeOwner4 transaction (initiated by owner1)
      const removeOwner4Tx = await multisigWallet.removeOwner(owner4.address);

      // Wait for removeOwner4 transaction to be mined
      const removeOwner4Receipt = await removeOwner4Tx.wait();

      // get the transaction index from the event logs and check Submit event logs

      const removeOnwer4Block = removeOwner4Receipt.blockNumber;

      // Filter for submit events in the receipt
      const submitRemoveOwner4TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        removeOnwer4Block,
        removeOnwer4Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitRemoveOwner4TxEvents.length).to.equal(1);

      const submitRemoveOwner4TxEvent = submitRemoveOwner4TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(submitRemoveOwner4TxEvent.args._transactionType).to.equal(4n);
      expect(submitRemoveOwner4TxEvent.args.to).to.equal(owner4.address);
      expect(submitRemoveOwner4TxEvent.args.value).to.equal(0n);
      expect(submitRemoveOwner4TxEvent.args.tokenAddress).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(submitRemoveOwner4TxEvent.args.amountOrTokenId).to.equal(0n);
      expect(submitRemoveOwner4TxEvent.args.owner).to.equal(owner1.address);
      expect(submitRemoveOwner4TxEvent.args.data).to.equal("0x");

      // Extract txIndex from the event arguments
      const removeOwner4TxIndex = submitRemoveOwner4TxEvent.args.txIndex;

      // owner3 confirms removeOwner4

      // Connect onwer3 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner3);

      // confirm transaction
      const owner3ConfirmRemoveOwner4Tx =
        await multisigWallet.confirmTransaction(removeOwner4TxIndex);

      // Wait for confirm transaction to be mined
      const owner3ConfirmRemoveOwner4Receipt =
        await owner3ConfirmRemoveOwner4Tx.wait();

      // check confirm event logs

      const owner3ConfirmRemoveOwner4Block =
        owner3ConfirmRemoveOwner4Receipt.blockNumber;

      // Filter for confirm events in the receipt
      const owner3ConfirmRemoveOwner4TxEvents =
        await multisigWallet.queryFilter(
          "ConfirmTransaction",
          owner3ConfirmRemoveOwner4Block,
          owner3ConfirmRemoveOwner4Block
        );

      // Ensure that one SubmitTransaction event was emitted
      expect(owner3ConfirmRemoveOwner4TxEvents.length).to.equal(1);

      const owner3ConfirmRemoveOwner4TxEvent =
        owner3ConfirmRemoveOwner4TxEvents[0];

      // Assert that the Event is emitted as expected
      expect(owner3ConfirmRemoveOwner4TxEvent.args.owner).to.equal(
        owner3.address
      );
      expect(owner3ConfirmRemoveOwner4TxEvent.args.txIndex).to.equal(
        removeOwner4TxIndex
      );

      // owner2 confirms removeOwner4

      // Connect onwer2 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner2);

      // confirm transaction
      const owner2ConfirmRemoveOwner4Tx =
        await multisigWallet.confirmTransaction(removeOwner4TxIndex);

      // Wait for confirm transaction to be mined
      const owner2ConfirmRemoveOwner4Receipt =
        await owner2ConfirmRemoveOwner4Tx.wait();

      // Fetch Owners
      const _threeOwners = await multisigWallet.getOwners();
      const threeOwnerCount = await multisigWallet.getOwnerCount();

      //Assert that owner1, owner2, owner3 and owner4 are the Owners
      expect(_threeOwners).to.eql([
        owner1.address,
        owner2.address,
        owner3.address,
      ]);
      expect(threeOwnerCount).to.eql(3n);
    }),
    it("can remove Owner3", async function () {
      // Connect onwer2 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner2);

      // Send removeOwner3 transaction (initiated by owner2)
      const removeOwner3Tx = await multisigWallet.removeOwner(owner3.address);

      // Wait for removeOwner3 transaction to be mined
      const removeOwner3Receipt = await removeOwner3Tx.wait();

      // get the transaction index from the event logs and check Submit event logs

      const removeOnwer3Block = removeOwner3Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const submitRemoveOwner3TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        removeOnwer3Block,
        removeOnwer3Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitRemoveOwner3TxEvents.length).to.equal(1);

      const submitRemoveOwner3TxEvent = submitRemoveOwner3TxEvents[0];

      // Extract txIndex from the event arguments
      const removeOwner3TxIndex = submitRemoveOwner3TxEvent.args.txIndex;

      // owner1 confirms removeOwner3

      // Connect onwer1 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner1);

      // confirm transaction
      const owner1ConfirmRemoveOwner3Tx =
        await multisigWallet.confirmTransaction(removeOwner3TxIndex);

      // Wait for confirm transaction to be mined
      const owner1ConfirmRemoveOwner3Receipt =
        await owner1ConfirmRemoveOwner3Tx.wait();

      // Fetch Owners
      const _twoOwners = await multisigWallet.getOwners();
      const twoOwnerCount = await multisigWallet.getOwnerCount();

      //Assert that owner1, owner2, owner3 and owner4 are the Owners
      expect(_twoOwners).to.eql([owner1.address, owner2.address]);
      expect(twoOwnerCount).to.eql(2n);
    }),
    it("can remove Owner2", async function () {
      // Connect onwer2 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner2);

      // Send removeOwner3 transaction (initiated by owner2)
      const removeOwner2Tx = await multisigWallet.removeOwner(owner2.address);

      // Wait for removeOwner3 transaction to be mined
      const removeOwner2Receipt = await removeOwner2Tx.wait();

      // get the transaction index from the event logs and check Submit event logs

      const removeOnwer2Block = removeOwner2Receipt.blockNumber;

      // Filter for reveived events in the receipt
      const submitRemoveOwner2TxEvents = await multisigWallet.queryFilter(
        "SubmitTransaction",
        removeOnwer2Block,
        removeOnwer2Block
      );

      // Ensure that  one SubmitTransaction event was emitted
      expect(submitRemoveOwner2TxEvents.length).to.equal(1);

      const submitRemoveOwner2TxEvent = submitRemoveOwner2TxEvents[0];

      // Extract txIndex from the event arguments
      const removeOwner2TxIndex = submitRemoveOwner2TxEvent.args.txIndex;

      // owner1 confirms removeOwner2

      // Connect onwer1 to the MultisigWallet contract
      multisigWallet = multisigWallet.connect(owner1);

      // confirm transaction
      const owner1ConfirmRemoveOwner2Tx =
        await multisigWallet.confirmTransaction(removeOwner2TxIndex);

      // Wait for confirm transaction to be mined
      const owner1ConfirmRemoveOwner2Receipt =
        await owner1ConfirmRemoveOwner2Tx.wait();

      // Fetch Owners
      const _oneOwner = await multisigWallet.getOwners();
      const oneOwnerCount = await multisigWallet.getOwnerCount();

      //Assert that owner1, owner2, owner3 and owner4 are the Owners
      expect(_oneOwner).to.eql([owner1.address]);
      expect(oneOwnerCount).to.eql(1n);
    });
});
