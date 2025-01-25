// change the "tokenId"s and "bigIntTokenId" before every run!

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
  let beforeBalances = {};

  //   let provider;

  //   // Environment variables
  //   const {
  //     MULTISIGWALLET_ADDRESS,
  //     SIMPLEERC20_ADDRESS,
  //     SIMPLEERC721_ADDRESS,
  //     OWNER1_ADDRESS,
  //     OWNER1_PRIVATE_KEY,
  //     OWNER2_ADDRESS,
  //     OWNER2_PRIVATE_KEY,
  //     OWNER3_ADDRESS,
  //     OWNER3_PRIVATE_KEY,
  //     OWNER4_ADDRESS,
  //     OWNER4_PRIVATE_KEY,
  //     OWNER5_ADDRESS,
  //     OWNER5_PRIVATE_KEY,
  //     SEPOLIA_RPC_URL,
  //   } = process.env;

  // Constants
  const DEPOSIT_AMOUNT = ethers.parseEther("0.01"); // 0.01 ETH
  const GAS_MARGIN = ethers.parseEther("0.001"); // 0.001 ETH margin for gas discrepancies

  before(async function () {
    // if (
    //   !MULTISIGWALLET_ADDRESS ||
    //   !OWNER1_ADDRESS ||
    //   !OWNER1_PRIVATE_KEY ||
    //   !SEPOLIA_RPC_URL ||
    //   !SIMPLEERC20_ADDRESS ||
    //   !SIMPLEERC721_ADDRESS ||
    //   !OWNER2_ADDRESS ||
    //   !OWNER2_PRIVATE_KEY ||
    //   !OWNER3_ADDRESS ||
    //   !OWNER3_PRIVATE_KEY ||
    //   !OWNER4_ADDRESS ||
    //   !OWNER4_PRIVATE_KEY ||
    //   !OWNER5_ADDRESS ||
    //   !OWNER5_PRIVATE_KEY
    // ) {
    //   throw new Error(
    //     "Please ensure MULTISIGWALLET_ADDRESS, OWNER1_ADDRESS, OWNER1_PRIVATE_KEY, SEPOLIA_RPC_URL, SIMPLEERC20_ADDRESS, and SIMPLEERC721_ADDRESS are set in your .env file"
    //   );
    // }

    // // Initialize provider for Sepolia
    // provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);

    // // Initialize signers using the private key
    // owner1 = new ethers.Wallet(OWNER1_PRIVATE_KEY, provider);
    // owner2 = new ethers.Wallet(OWNER2_PRIVATE_KEY, provider);
    // owner3 = new ethers.Wallet(OWNER3_PRIVATE_KEY, provider);
    // owner4 = new ethers.Wallet(OWNER4_PRIVATE_KEY, provider);
    // owner5 = new ethers.Wallet(OWNER5_PRIVATE_KEY, provider);

    // // Normalize and compare addresses using ethers.js
    // expect(ethers.getAddress(owner1.address)).to.equal(
    //   ethers.getAddress(OWNER1_ADDRESS)
    // );
    // expect(ethers.getAddress(owner2.address)).to.equal(
    //   ethers.getAddress(OWNER2_ADDRESS)
    // );
    // expect(ethers.getAddress(owner3.address)).to.equal(
    //   ethers.getAddress(OWNER3_ADDRESS)
    // );
    // expect(ethers.getAddress(owner4.address)).to.equal(
    //   ethers.getAddress(OWNER4_ADDRESS)
    // );
    // expect(ethers.getAddress(owner5.address)).to.equal(
    //   ethers.getAddress(OWNER5_ADDRESS)
    // );

    //     // Connect owner1 to the MultisigWallet contract
    //     multisigWallet = await ethers.getContractAt(
    //       "MultisigWallet",
    //       MULTISIGWALLET_ADDRESS,
    //       owner1
    //     );

    //// delete this Local environment
    // Fetch signers
    [owner1, owner2, owner3, owner4, owner5] = await ethers.getSigners();

    // get initial owner balances
    beforeBalances.owner1 = await ethers.provider.getBalance(owner1.address);
    beforeBalances.owner2 = await ethers.provider.getBalance(owner2.address);
    beforeBalances.owner3 = await ethers.provider.getBalance(owner3.address);
    beforeBalances.owner4 = await ethers.provider.getBalance(owner4.address);
    beforeBalances.owner5 = await ethers.provider.getBalance(owner5.address);

    // Log the signers and their initial balances in ETH
    console.log("Initial balances of owners:");
    console.log(
      "Owner1:",
      owner1.address,
      "| Balance (ETH):",
      ethers.formatEther(beforeBalances.owner1)
    );
    console.log(
      "Owner2:",
      owner2.address,
      "| Balance (ETH):",
      ethers.formatEther(beforeBalances.owner2)
    );
    console.log(
      "Owner3:",
      owner3.address,
      "| Balance (ETH):",
      ethers.formatEther(beforeBalances.owner3)
    );
    console.log(
      "Owner4:",
      owner4.address,
      "| Balance (ETH):",
      ethers.formatEther(beforeBalances.owner4)
    );
    console.log(
      "Owner5:",
      owner5.address,
      "| Balance (ETH):",
      ethers.formatEther(beforeBalances.owner5)
    );

    // Deploy the contract
    const MultisigWalletFactory = await ethers.getContractFactory(
      "MultisigWallet"
    );
    multisigWallet = await MultisigWalletFactory.deploy([owner1.address]);
    // Verify that the contract address is defined
    expect(multisigWallet.target).to.properAddress;
    expect(await ethers.provider.getCode(multisigWallet.target)).to.not.equal(
      "0x"
    );
    console.log("MultisigWallet deployed at:", multisigWallet.target);
  });

  it("MultisigWallet can receive deposits and withdraw with only one owner", async function () {
    // Fetch initial balances
    const initialOwner1Balance = await ethers.provider.getBalance(
      owner1.address
    );
    const initialWalletBalance = await ethers.provider.getBalance(
      multisigWallet.target
    );
    //// replace ethers.provider with provide

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
    //// replace ethers.provider with provide

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
  });

  it("can send ERC20 Tokens on behalf", async function () {
    // Deploy SimpleERC20 contract with initialSupply to owner1

    // Connect to owner1
    const SimpleERC20Factory = await ethers.getContractFactory("SimpleERC20");
    const initialSupply = ethers.parseEther("100"); // 1000 tokens with 18 decimals

    // Deploy the contract connected as owner1
    const simpleERC20 = await SimpleERC20Factory.connect(owner1).deploy(
      initialSupply
    );

    await simpleERC20.waitForDeployment();

    // Now, simpleERC20 is deployed, and owner1 has initialSupply of tokens

    // Verify that owner1 has the tokens
    const initialOwner1Balance = await simpleERC20.balanceOf(owner1.address);
    // Correct comparison using BigInt
    expect(initialOwner1Balance >= ethers.parseEther("100")).to.be.true;

    const initialOwner2Balance = await simpleERC20.balanceOf(owner2.address);

    // Now, let owner1 approve the multisigWallet to spend tokens on their behalf
    const transferAmount = ethers.parseEther("100");

    try {
      // Owner1 approves the multisigWallet to spend tokens
      const approveTx = await simpleERC20
        .connect(owner1)
        .approve(multisigWallet.target, transferAmount);
      await approveTx.wait();
    } catch (error) {
      console.error("Error during token approval:", error);
      throw error;
    }

    // Verify that multisigWallet has allowance from owner1
    const allowance = await simpleERC20.allowance(
      owner1.address,
      multisigWallet.target
    );
    expect(allowance).to.equal(transferAmount);

    // Now, owner2 submits a transferERC20 transaction to transfer tokens from multisigWallet to owner2

    // Connect multisigWallet as owner2
    multisigWallet = multisigWallet.connect(owner2);

    // Owner2 calls transferFromERC20
    const submitTx = await multisigWallet.transferFromERC20(
      simpleERC20.target,
      owner1.address,
      owner2.address,
      transferAmount
    );

    const submitReceipt = await submitTx.wait();

    // Check emitted events for submit and confirm (since confirm is triggered automatically after submitting)
    const submitBlock = submitReceipt.blockNumber;

    // Filter for SubmitTransaction events
    const submitEvents = await multisigWallet.queryFilter(
      "SubmitTransaction",
      submitBlock,
      submitBlock
    );

    // Ensure that one SubmitTransaction event was emitted
    expect(submitEvents.length).to.equal(1);

    const submitEvent = submitEvents[0];

    // Now, encode the data as in the contract to compare
    const expectedData = simpleERC20.interface.encodeFunctionData(
      "transferFrom",
      [
        owner1.address, // _from
        owner2.address, // _to
        transferAmount, // _amount
      ]
    );

    // Assert that the Event is emitted as expected
    expect(submitEvent.args._transactionType).to.equal(1n); // For ERC20
    expect(submitEvent.args.to).to.equal(owner2.address);
    expect(submitEvent.args.value).to.equal(0n);
    expect(submitEvent.args.tokenAddress).to.equal(simpleERC20.target);
    expect(submitEvent.args.amountOrTokenId).to.equal(transferAmount);
    expect(submitEvent.args.owner).to.equal(owner2.address);
    expect(submitEvent.args.data).to.be.equal(expectedData);

    // Confirm is triggered automatically after submitting
    // Check the ConfirmTransaction event
    const confirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      submitBlock,
      submitBlock
    );

    expect(confirmEvents.length).to.equal(1);

    const confirmEvent = confirmEvents[0];

    expect(confirmEvent.args.owner).to.equal(owner2.address);
    expect(confirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Now, owner1 needs to confirm the transaction

    // Connect multisigWallet as owner1
    multisigWallet = multisigWallet.connect(owner1);

    // Owner1 confirms the transaction
    const confirmTx = await multisigWallet.confirmTransaction(
      submitEvent.args.txIndex
    );

    const confirmReceipt = await confirmTx.wait();

    // This should trigger the execution as well

    // Check event logs for confirm and execution
    const confirmBlock = confirmReceipt.blockNumber;

    // Check the ConfirmTransaction event
    const owner1ConfirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(owner1ConfirmEvents.length).to.equal(1);

    const owner1ConfirmEvent = owner1ConfirmEvents[0];

    expect(owner1ConfirmEvent.args.owner).to.equal(owner1.address);
    expect(owner1ConfirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Check the ExecuteTransaction event
    const executeEvents = await multisigWallet.queryFilter(
      "ExecuteTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(executeEvents.length).to.equal(1);

    const executeEvent = executeEvents[0];

    expect(executeEvent.args._transactionType).to.equal(1n); // ERC20
    expect(executeEvent.args.txIndex).to.equal(submitEvent.args.txIndex);
    expect(executeEvent.args.to).to.equal(owner2.address);
    expect(executeEvent.args.value).to.equal(0n);
    expect(executeEvent.args.tokenAddress).to.equal(simpleERC20.target);
    expect(executeEvent.args.amountOrTokenId).to.equal(transferAmount);
    expect(executeEvent.args.owner).to.equal(owner1.address);
    expect(executeEvent.args.data).to.equal(expectedData);

    // Now, verify that owner2 has received the tokens
    const owner2Balance = await simpleERC20.balanceOf(owner2.address);
    expect(owner2Balance).to.equal(initialOwner2Balance + transferAmount);

    // Also, verify that owner1's balance has decreased
    const owner1FinalBalance = await simpleERC20.balanceOf(owner1.address);
    expect(owner1FinalBalance).to.equal(initialOwner1Balance - transferAmount);
  });

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
    const Owner2confirmAddOwner3Receipt = await owner2ConfirmAddOwner3Tx.wait();

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
  });
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
    const Owner1confirmAddOwner4Receipt = await owner1ConfirmAddOwner4Tx.wait();

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
  });
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
    const owner3ConfirmAddOwner5Receipt = await owner3ConfirmAddOwner5Tx.wait();

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
    expect(owner3ConfirmOwner5TxEvent.args.txIndex).to.equal(addOwner5TxIndex);

    // owner1 confirms addOwner5

    // Connect onwer1 to the MultisigWallet contract
    multisigWallet = multisigWallet.connect(owner1);

    // confirm transaction
    const owner1ConfirmAddOwner5Tx = await multisigWallet.confirmTransaction(
      addOwner5TxIndex
    );

    // Wait for deposit transaction to be mined
    const owner1ConfirmAddOwner5Receipt = await owner1ConfirmAddOwner5Tx.wait();

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
  });
  it("can send ETH with 5 owners", async function () {
    multisigWallet = multisigWallet.connect(owner1);

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

    // Initiate withdrawal transaction
    const submitWithdrawalTx = await multisigWallet.sendETH(
      owner1.address,
      walletBalanceAfterDeposit
    );

    // Wait for withdrawal transaction to be mined
    const submitWithdrawalReceipt = await submitWithdrawalTx.wait();

    // Track gas cost for withdrawal transaction
    const gasUsedSubmitWithdrawal =
      submitWithdrawalReceipt.gasUsed * submitWithdrawalReceipt.gasPrice;

    const submitWithdrawalBlock = submitWithdrawalReceipt.blockNumber;

    // Filter for reveived events in the receipt
    const submitWithdrawalTxEvents = await multisigWallet.queryFilter(
      "SubmitTransaction",
      submitWithdrawalBlock,
      submitWithdrawalBlock
    );

    // Ensure that  one SubmitTransaction event was emitted
    expect(submitWithdrawalTxEvents.length).to.equal(1);

    const submitWithdrawalTxEvent = submitWithdrawalTxEvents[0];

    // Extract txIndex from the event arguments
    const submitWithdrawalTxIndex = submitWithdrawalTxEvent.args.txIndex;

    // owner4 confirms removeOwner5

    // Connect onwer4 to the MultisigWallet contract
    multisigWallet = multisigWallet.connect(owner4);

    // confirm transaction
    const owner4ConfirmWithdrawal = await multisigWallet.confirmTransaction(
      submitWithdrawalTxIndex
    );

    // Wait for confirm transaction to be mined
    const owner4ConfirmWithdrawalReceipt = await owner4ConfirmWithdrawal.wait();

    // Connect onwer2 to the MultisigWallet contract
    multisigWallet = multisigWallet.connect(owner2);

    // confirm transaction
    const owner2ConfirmWithdrawal = await multisigWallet.confirmTransaction(
      submitWithdrawalTxIndex
    );

    // Wait for confirm transaction to be mined
    const owner2ConfirmWithdrawalReceipt = await owner2ConfirmWithdrawal.wait();

    // Fetch final wallet balance
    const finalWalletBalance = await ethers.provider.getBalance(
      //// replace ethers.provider with provide
      multisigWallet.target
    );

    // Assertions
    expect(finalWalletBalance).to.equal(0n);

    // Fetch final owner1 balance
    const finalOwner1Balance = await ethers.provider.getBalance(owner1.address); //// replace ethers.provider with provide
    //// replace ethers.provider with provide

    const expectedFinalOwner1Balance =
      initialOwner1Balance - gasUsedDeposit - gasUsedSubmitWithdrawal;

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
  });

  it("can receive and send ERC721 Tokens", async function () {
    // Deploy SimpleERC721 contract and mint a token to owner1

    // Connect to owner1
    const SimpleERC721Factory = await ethers.getContractFactory("SimpleERC721");

    // Deploy the contract connected as owner1
    const simpleERC721 = await SimpleERC721Factory.connect(owner1).deploy();

    // Mint a new token to owner1
    const tokenId = 1; // this needs to be changed every time this test gets ran with the same simpleERC721 deployment (use 2 next) this can maybe be done with a script
    const bigIntTokenId = 1n; // this needs to be changed every time this test gets ran with the same simpleERC721 deployment (use 2 next) this can maybe be done with a script
    const mintTx = await simpleERC721
      .connect(owner1)
      .mint(owner1.address, tokenId);
    await mintTx.wait();

    // Verify that owner1 owns the token
    const ownerOfToken = await simpleERC721.ownerOf(tokenId);
    expect(ownerOfToken).to.equal(owner1.address);

    // Now, let owner1 transfer the token to the multisigWallet

    try {
      // Owner1 transfers the token to multisigWallet
      const transferTx = await simpleERC721
        .connect(owner1)
        .transferFrom(owner1.address, multisigWallet.target, tokenId);
      await transferTx.wait();
    } catch (error) {
      console.error("Error during ERC721 transfer:", error);
      throw error;
    }

    // Verify that multisigWallet has received the token
    const newOwnerOfToken = await simpleERC721.ownerOf(tokenId);
    expect(newOwnerOfToken).to.equal(multisigWallet.target);

    // Now, owner2 submits a safeTransferFromERC721 transaction to transfer the token from multisigWallet to owner2

    // Connect multisigWallet as owner2
    multisigWallet = multisigWallet.connect(owner2);

    // Owner2 calls safeTransferFromERC721
    const submitTx = await multisigWallet.safeTransferFromERC721(
      simpleERC721.target,
      multisigWallet.target, // _from
      owner2.address, // _to
      tokenId // _tokenId
    );

    const submitReceipt = await submitTx.wait();

    // Check emitted events for submit and confirm (since confirm is triggered automatically after submitting)
    const submitBlock = submitReceipt.blockNumber;

    // Filter for SubmitTransaction events
    const submitEvents = await multisigWallet.queryFilter(
      "SubmitTransaction",
      submitBlock,
      submitBlock
    );

    // Ensure that one SubmitTransaction event was emitted
    expect(submitEvents.length).to.equal(1);

    const submitEvent = submitEvents[0];

    // Now, encode the data as in the contract to compare
    const expectedData = simpleERC721.interface.encodeFunctionData(
      "safeTransferFrom(address,address,uint256)",
      [
        multisigWallet.target, // _from
        owner2.address, // _to
        tokenId, // _tokenId
      ]
    );

    // Assert that the Event is emitted as expected
    expect(submitEvent.args._transactionType).to.equal(2n); // For ERC721
    expect(submitEvent.args.to).to.equal(owner2.address);
    expect(submitEvent.args.value).to.equal(0n);
    expect(submitEvent.args.tokenAddress).to.equal(simpleERC721.target);
    expect(submitEvent.args.amountOrTokenId).to.equal(bigIntTokenId);
    expect(submitEvent.args.owner).to.equal(owner2.address);
    expect(submitEvent.args.data).to.equal(expectedData);

    // Confirm is triggered automatically after submitting
    // Check the ConfirmTransaction event
    const confirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      submitBlock,
      submitBlock
    );

    expect(confirmEvents.length).to.equal(1);

    const confirmEvent = confirmEvents[0];

    expect(confirmEvent.args.owner).to.equal(owner2.address);
    expect(confirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Now, owner4 needs to confirm the transaction

    // Connect multisigWallet as owner4
    multisigWallet = multisigWallet.connect(owner4);

    // Owner4 confirms the transaction
    const confirmTxOwner4 = await multisigWallet.confirmTransaction(
      submitEvent.args.txIndex
    );

    await confirmTxOwner4.wait();

    // Now, owner1 needs to confirm the transaction

    // Connect multisigWallet as owner1
    multisigWallet = multisigWallet.connect(owner1);

    // Owner1 confirms the transaction
    const confirmTx = await multisigWallet.confirmTransaction(
      submitEvent.args.txIndex
    );

    const confirmReceipt = await confirmTx.wait();

    // This should trigger the execution as well

    // Check event logs for confirm and execution
    const confirmBlock = confirmReceipt.blockNumber;

    // Check the ConfirmTransaction event
    const owner1ConfirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(owner1ConfirmEvents.length).to.equal(1);

    const owner1ConfirmEvent = owner1ConfirmEvents[0];

    expect(owner1ConfirmEvent.args.owner).to.equal(owner1.address);
    expect(owner1ConfirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Check the ExecuteTransaction event
    const executeEvents = await multisigWallet.queryFilter(
      "ExecuteTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(executeEvents.length).to.equal(1);

    const executeEvent = executeEvents[0];

    expect(executeEvent.args._transactionType).to.equal(2n); // ERC721
    expect(executeEvent.args.txIndex).to.equal(submitEvent.args.txIndex);
    expect(executeEvent.args.to).to.equal(owner2.address);
    expect(executeEvent.args.value).to.equal(0n);
    expect(executeEvent.args.tokenAddress).to.equal(simpleERC721.target);
    expect(executeEvent.args.amountOrTokenId).to.equal(bigIntTokenId);
    expect(executeEvent.args.owner).to.equal(owner1.address);
    expect(executeEvent.args.data).to.equal(expectedData);

    // Now, verify that owner2 has received the token
    const finalOwnerOfToken = await simpleERC721.ownerOf(tokenId);
    expect(finalOwnerOfToken).to.equal(owner2.address);
  });

  it("can submit and execute an 'other' transaction (approve ERC721 for owner4)", async function () {
    // Deploy SimpleERC721 contract and mint a token to owner1

    // Connect to owner1
    const SimpleERC721Factory = await ethers.getContractFactory("SimpleERC721");

    // Deploy the contract connected as owner1
    const simpleERC721 = await SimpleERC721Factory.connect(owner1).deploy();

    // Mint a new token to owner1
    const tokenId = 103; // this needs to be changed every time this test gets ran with the same simpleERC721 deployment (use 103 nex) this can maybe done with a script
    const mintTx = await simpleERC721
      .connect(owner1)
      .mint(owner1.address, tokenId);
    await mintTx.wait();

    // Verify that owner1 owns the token
    const ownerOfToken = await simpleERC721.ownerOf(tokenId);
    expect(ownerOfToken).to.equal(owner1.address);

    try {
      // Owner1 transfers the token to multisigWallet
      const transferTx = await simpleERC721
        .connect(owner1)
        .transferFrom(owner1.address, multisigWallet.target, tokenId);
      await transferTx.wait();
    } catch (error) {
      console.error("Error during ERC721 transfer:", error);
      throw error;
    }

    // Verify that multisigWallet has received the token
    const newOwnerOfToken = await simpleERC721.ownerOf(tokenId);
    expect(newOwnerOfToken).to.equal(multisigWallet.target);

    // Now, owner2 submits an 'other' transaction to approve owner4 to manage the token

    // Prepare the data for the `approve` call
    const approvalData = simpleERC721.interface.encodeFunctionData("approve", [
      owner4.address, // Approve owner4 to manage the token
      tokenId, // The tokenId of the token held by multisigWallet
    ]);

    // Connect multisigWallet as owner2
    multisigWallet = multisigWallet.connect(owner2);

    let submitTx;
    let submitReceipt;
    try {
      // Owner2 submits the 'other' transaction
      submitTx = await multisigWallet.submitTransaction(
        6n, // Enum for "other" transaction type (TransactionType.Other)
        simpleERC721.target, // The contract we're interacting with (SimpleERC721)
        0, // No ETH value being sent
        approvalData // The data encoding the approve function call
      );
      submitReceipt = await submitTx.wait();
    } catch (error) {
      console.error("Error submitting 'other' transaction:", error);
      throw error;
    }

    // Check emitted events for submit and confirm (since confirm is triggered automatically after submitting)
    const submitBlock = submitReceipt.blockNumber;

    // Filter for SubmitTransaction events
    const submitEvents = await multisigWallet.queryFilter(
      "SubmitTransaction",
      submitBlock,
      submitBlock
    );

    // Ensure that one SubmitTransaction event was emitted
    expect(submitEvents.length).to.equal(1);

    const submitEvent = submitEvents[0];

    // Assert that the Event is emitted as expected
    expect(submitEvent.args._transactionType).to.equal(6n); // For "other"
    expect(submitEvent.args.to).to.equal(simpleERC721.target);
    expect(submitEvent.args.value).to.equal(0n);
    expect(submitEvent.args.tokenAddress).to.equal(
      "0x0000000000000000000000000000000000000000"
    ); // No tokenAddress for "other"
    expect(submitEvent.args.amountOrTokenId).to.equal(0n);
    expect(submitEvent.args.owner).to.equal(owner2.address);
    expect(submitEvent.args.data).to.equal(approvalData);

    // Confirm is triggered automatically after submitting
    // Check the ConfirmTransaction event
    const confirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      submitBlock,
      submitBlock
    );

    expect(confirmEvents.length).to.equal(1);

    const confirmEvent = confirmEvents[0];

    expect(confirmEvent.args.owner).to.equal(owner2.address);
    expect(confirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Now, owner4 needs to confirm the transaction

    // Connect multisigWallet as owner4
    multisigWallet = multisigWallet.connect(owner4);

    // Owner4 confirms the transaction
    const confirmTxOwner4 = await multisigWallet.confirmTransaction(
      submitEvent.args.txIndex
    );

    await confirmTxOwner4.wait();

    // Now, owner1 needs to confirm the transaction

    // Connect multisigWallet as owner1
    multisigWallet = multisigWallet.connect(owner1);

    // Owner1 confirms the transaction
    const confirmTx = await multisigWallet.confirmTransaction(
      submitEvent.args.txIndex
    );

    const confirmReceipt = await confirmTx.wait();

    // This should trigger the execution as well

    // Check event logs for confirm and execution
    const confirmBlock = confirmReceipt.blockNumber;

    // Check the ConfirmTransaction event
    const owner1ConfirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(owner1ConfirmEvents.length).to.equal(1);

    const owner1ConfirmEvent = owner1ConfirmEvents[0];

    expect(owner1ConfirmEvent.args.owner).to.equal(owner1.address);
    expect(owner1ConfirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Check the ExecuteTransaction event
    const executeEvents = await multisigWallet.queryFilter(
      "ExecuteTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(executeEvents.length).to.equal(1);

    const executeEvent = executeEvents[0];

    expect(executeEvent.args._transactionType).to.equal(6n); // For "other"
    expect(executeEvent.args.txIndex).to.equal(submitEvent.args.txIndex);
    expect(executeEvent.args.to).to.equal(simpleERC721.target);
    expect(executeEvent.args.value).to.equal(0n);
    expect(executeEvent.args.tokenAddress).to.equal(
      "0x0000000000000000000000000000000000000000"
    ); // No tokenAddress for "other"
    expect(executeEvent.args.amountOrTokenId).to.equal(0n);
    expect(executeEvent.args.owner).to.equal(owner1.address);
    expect(executeEvent.args.data).to.equal(approvalData);

    // Now, verify that owner4 has been approved to manage the token
    const approvedAddress = await simpleERC721.getApproved(tokenId);
    expect(approvedAddress).to.equal(owner4.address);
  });

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
    const owner4ConfirmRemoveOwner5Tx = await multisigWallet.confirmTransaction(
      removeOwner5TxIndex
    );

    // Wait for confirm transaction to be mined
    const owner4ConfirmRemoveOwner5Receipt =
      await owner4ConfirmRemoveOwner5Tx.wait();

    // check confirm event logs

    const owner4ConfirmRemoveOwner5Block =
      owner4ConfirmRemoveOwner5Receipt.blockNumber;

    // Filter for reveived events in the receipt
    const owner4ConfirmRemoveOwner5TxEvents = await multisigWallet.queryFilter(
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
    const owner1ConfirmRemoveOwner5Tx = await multisigWallet.confirmTransaction(
      removeOwner5TxIndex
    );

    // Wait for confirm transaction to be mined
    const owner1ConfirmRemoveOwner5Receipt =
      await owner1ConfirmRemoveOwner5Tx.wait();

    // check confirm event logs

    const owner1ConfirmRemoveOwner5Block =
      owner1ConfirmRemoveOwner5Receipt.blockNumber;

    // Filter for reveived events in the receipt
    const owner1ConfirmRemoveOwner5TxEvents = await multisigWallet.queryFilter(
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
    const owner2ConfirmRemoveOwner5Tx = await multisigWallet.confirmTransaction(
      removeOwner5TxIndex
    );

    // Wait for confirm transaction to be mined
    const owner2ConfirmRemoveOwner5Receipt =
      await owner2ConfirmRemoveOwner5Tx.wait();

    // check confirm event logs

    const owner2ConfirmRemoveOwner5Block =
      owner2ConfirmRemoveOwner5Receipt.blockNumber;

    // Filter for confirm events in the receipt
    const owner2ConfirmRemoveOwner5TxEvents = await multisigWallet.queryFilter(
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
  });
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
    const owner3ConfirmRemoveOwner4Tx = await multisigWallet.confirmTransaction(
      removeOwner4TxIndex
    );

    // Wait for confirm transaction to be mined
    const owner3ConfirmRemoveOwner4Receipt =
      await owner3ConfirmRemoveOwner4Tx.wait();

    // check confirm event logs

    const owner3ConfirmRemoveOwner4Block =
      owner3ConfirmRemoveOwner4Receipt.blockNumber;

    // Filter for confirm events in the receipt
    const owner3ConfirmRemoveOwner4TxEvents = await multisigWallet.queryFilter(
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
    const owner2ConfirmRemoveOwner4Tx = await multisigWallet.confirmTransaction(
      removeOwner4TxIndex
    );

    // Wait for confirm transaction to be mined
    const owner2ConfirmRemoveOwner4Receipt =
      await owner2ConfirmRemoveOwner4Tx.wait();

    // Fetch Owners
    const _threeOwners = await multisigWallet.getOwners();
    const threeOwnerCount = await multisigWallet.getOwnerCount();

    //Assert that owner1, owner2 and owner3 are the Owners
    expect(_threeOwners).to.eql([
      owner1.address,
      owner2.address,
      owner3.address,
    ]);
    expect(threeOwnerCount).to.eql(3n);
  });

  it("can batch-transfer multiple assets in one transaction", async function () {
    // We'll do a single transaction that transfers ETH, ERC20, and ERC721
    // from the MultisigWallet to various owners in one go.

    // ---------------------------------------------------------------------
    // 1. Deploy fresh ERC20 and ERC721 within this test
    // ---------------------------------------------------------------------
    const SimpleERC20Factory = await ethers.getContractFactory("SimpleERC20");
    const initialSupply = ethers.parseEther("1000");
    const simpleERC20 = await SimpleERC20Factory.connect(owner1).deploy(
      initialSupply
    );
    await simpleERC20.waitForDeployment();

    const SimpleERC721Factory = await ethers.getContractFactory("SimpleERC721");
    const simpleERC721 = await SimpleERC721Factory.connect(owner1).deploy();
    await simpleERC721.waitForDeployment();

    // We'll deposit 0.05 ETH, deposit 50 ERC20 into the wallet,
    // and transfer an NFT into it. Then we do the batch transfer.

    // ---------------------------------------------------------------------
    // 2. Deposit 0.05 ETH from owner1 into MultisigWallet
    // ---------------------------------------------------------------------

    // 2A. Record initial balances
    const initialOwner1EthBalance = await ethers.provider.getBalance(
      owner1.address
    );
    const initialWalletEthBalance = await ethers.provider.getBalance(
      multisigWallet.target
    );
    //// replace ethers.provider with provide

    // 2B. Perform the deposit from owner1
    const depositEthAmount = ethers.parseEther("0.05");
    const depositTx = await owner1.sendTransaction({
      to: multisigWallet.target,
      value: depositEthAmount,
    });
    const depositReceipt = await depositTx.wait();
    const gasUsedDeposit = depositReceipt.gasUsed * depositReceipt.gasPrice;

    // 2C. Check final wallet ETH balance & events
    const walletBalanceAfterDeposit = await ethers.provider.getBalance(
      multisigWallet.target
    );
    //// replace ethers.provider with provide

    expect(walletBalanceAfterDeposit).to.equal(
      initialWalletEthBalance + depositEthAmount
    );

    const depositBlock = depositReceipt.blockNumber;
    const depositEvents = await multisigWallet.queryFilter(
      "Deposit",
      depositBlock,
      depositBlock
    );
    expect(depositEvents.length).to.equal(1);
    const depositEvent = depositEvents[0];
    expect(depositEvent.args.sender).to.equal(owner1.address);
    expect(depositEvent.args.amountOrTokenId).to.equal(depositEthAmount);
    expect(depositEvent.args.balance).to.equal(walletBalanceAfterDeposit);

    // 2D. Check final balance of owner1 (within a small margin for gas)
    const finalOwner1EthBalance = await ethers.provider.getBalance(
      owner1.address
    );
    //// replace ethers.provider with provide

    const expectedOwner1BalanceAfterDeposit =
      initialOwner1EthBalance - depositEthAmount - gasUsedDeposit;
    const diffOwner1Balance =
      finalOwner1EthBalance - expectedOwner1BalanceAfterDeposit;
    const absDiffOwner1Balance =
      diffOwner1Balance < 0n ? -diffOwner1Balance : diffOwner1Balance;
    expect(absDiffOwner1Balance <= GAS_MARGIN).to.be.true;

    // ---------------------------------------------------------------------
    // 3. Transfer 50 ERC20 from owner1 to MultisigWallet
    // ---------------------------------------------------------------------
    const initialWalletERC20Balance = await simpleERC20.balanceOf(
      multisigWallet.target
    );
    const erc20TransferAmount = ethers.parseEther("50");

    // 3A. Mint or ensure owner1 has enough tokens, then transfer
    // (You already minted enough in earlier tests, but let's do it again if needed.)
    // We'll do a direct transfer: owner1 --> multisigWallet
    const transferERC20Tx = await simpleERC20.transfer(
      multisigWallet.target,
      erc20TransferAmount
    );
    await transferERC20Tx.wait();

    const finalWalletERC20Balance = await simpleERC20.balanceOf(
      multisigWallet.target
    );
    expect(finalWalletERC20Balance).to.equal(
      initialWalletERC20Balance + erc20TransferAmount
    );

    // ---------------------------------------------------------------------
    // 4. Mint and transfer an ERC721 token to the MultisigWallet
    // ---------------------------------------------------------------------
    const nftTokenId = 777; // Must be fresh each time if re-running on the same contract
    const mintTx = await simpleERC721.mint(owner1.address, nftTokenId);
    await mintTx.wait();

    // Check that owner1 is the NFT owner
    let nftOwner = await simpleERC721.ownerOf(nftTokenId);
    expect(nftOwner).to.equal(owner1.address);

    // Transfer NFT to MultisigWallet
    const transferERC721Tx = await simpleERC721.transferFrom(
      owner1.address,
      multisigWallet.target,
      nftTokenId
    );
    await transferERC721Tx.wait();

    // Check that MultisigWallet is now the owner
    nftOwner = await simpleERC721.ownerOf(nftTokenId);
    expect(nftOwner).to.equal(multisigWallet.target);

    // ---------------------------------------------------------------------
    // 5. Prepare the batchTransfer
    // ---------------------------------------------------------------------
    // We'll do 5 sub-transfers in one batch:
    //   1)  0.01 ETH -> owner2
    //   2)  20 ERC20 -> owner3
    //   3)  NFT with tokenId=777 -> owner2
    //   4)  10 ERC20 -> owner2
    //   5)  0.005 ETH -> owner3
    // We'll measure initial balances for owners2/3, then confirm final balances.

    // 5A. Record owners2/3 initial ETH balances
    const initialOwner2EthBalance = await ethers.provider.getBalance(
      owner2.address
    );
    const initialOwner3EthBalance = await ethers.provider.getBalance(
      owner3.address
    );
    //// replace ethers.provider with provide

    // 5B. Record owners2/3 initial ERC20 balances
    const initialOwner2ERC20Balance = await simpleERC20.balanceOf(
      owner2.address
    );
    const initialOwner3ERC20Balance = await simpleERC20.balanceOf(
      owner3.address
    );

    // 5C. The proposed batch transfers
    const batchTransfers = [
      {
        to: owner2.address,
        tokenAddress: ethers.ZeroAddress,
        value: ethers.parseEther("0.01"),
        tokenId: 0,
      },
      {
        to: owner3.address,
        tokenAddress: simpleERC20.target,
        value: ethers.parseEther("20"),
        tokenId: 0,
      },
      {
        to: owner2.address,
        tokenAddress: simpleERC721.target,
        value: 0,
        tokenId: nftTokenId,
      },
      {
        to: owner2.address,
        tokenAddress: simpleERC20.target,
        value: ethers.parseEther("10"),
        tokenId: 0,
      },
      {
        to: owner3.address,
        tokenAddress: ethers.ZeroAddress,
        value: ethers.parseEther("0.005"),
        tokenId: 0,
      },
    ];

    // ---------------------------------------------------------------------
    // 6. Submit the batchTransfer as owner2. This auto-confirms for owner2.
    // ---------------------------------------------------------------------
    multisigWallet = multisigWallet.connect(owner2);

    const submitTx2 = await multisigWallet.batchTransfer(batchTransfers);
    const submitReceipt2 = await submitTx2.wait();
    // Effective gasPrice (EIP-1559 can have base + maxFee; for Hardhat it's often simply gasPrice)
    const gasUsedBatchTx = submitReceipt2.gasUsed;
    const gasPriceBatchTx =
      submitReceipt2.effectiveGasPrice ?? submitReceipt2.gasPrice;
    // Total gas cost in WEI
    const totalGasCostBatchTx = gasUsedBatchTx * gasPriceBatchTx;

    const submitBlock2 = submitReceipt2.blockNumber;

    // Check the SubmitTransaction event
    const submitEvents2 = await multisigWallet.queryFilter(
      "SubmitTransaction",
      submitBlock2,
      submitBlock2
    );
    expect(submitEvents2.length).to.equal(1);
    const submitEvent2 = submitEvents2[0];
    expect(submitEvent2.args._transactionType).to.equal(5n); // enum: BatchTransaction
    const batchTxIndex = submitEvent2.args.txIndex;

    // Check the auto-confirm from owner2
    const confirmEvents2 = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      submitBlock2,
      submitBlock2
    );
    expect(confirmEvents2.length).to.equal(1);
    expect(confirmEvents2[0].args.owner).to.equal(owner2.address);
    expect(confirmEvents2[0].args.txIndex).to.equal(batchTxIndex);

    // ---------------------------------------------------------------------
    // 7. Confirm from a second owner to surpass 50% of 3 owners => triggers execution.
    //    We'll do it from owner1 (the richest) to pay the final gas.
    // ---------------------------------------------------------------------
    multisigWallet = multisigWallet.connect(owner1);

    // measure owner1's initial ETH balance
    const initialOwner1BalanceBeforeConfirm = await ethers.provider.getBalance(
      owner1.address
    );
    //// replace ethers.provider with provide

    const confirmTxOwner1 = await multisigWallet.confirmTransaction(
      batchTxIndex
    );
    const confirmReceiptOwner1 = await confirmTxOwner1.wait();
    const gasUsedOwner1Confirm =
      confirmReceiptOwner1.gasUsed * confirmReceiptOwner1.gasPrice;

    const confirmBlockOwner1 = confirmReceiptOwner1.blockNumber;

    // 7A. Check the ConfirmTransaction event from owner1
    const confirmEventsOwner1 = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      confirmBlockOwner1,
      confirmBlockOwner1
    );
    // Possibly confirm + execute are separate logs
    // But we just need to see exactly 1 confirm log from owner1 here
    const confirmEventOwner1 = confirmEventsOwner1.find(
      (ev) => ev.args.owner === owner1.address
    );
    expect(confirmEventOwner1).to.exist;
    expect(confirmEventOwner1.args.txIndex).to.equal(batchTxIndex);

    // 7B. The execution should happen now, so check ExecuteTransaction event
    const executeEvents2 = await multisigWallet.queryFilter(
      "ExecuteTransaction",
      confirmBlockOwner1,
      confirmBlockOwner1
    );
    expect(executeEvents2.length).to.equal(1);
    expect(executeEvents2[0].args._transactionType).to.equal(5n);
    expect(executeEvents2[0].args.txIndex).to.equal(batchTxIndex);
    expect(executeEvents2[0].args.owner).to.equal(owner1.address);

    // 7C. Check the 5 BatchTransferExecuted sub-events
    const batchTransferExecutedEvents = await multisigWallet.queryFilter(
      "BatchTransferExecuted",
      confirmBlockOwner1,
      confirmBlockOwner1
    );
    expect(batchTransferExecutedEvents.length).to.equal(batchTransfers.length);

    // 7D. Check final owner1 balance with margin for gas usage
    const finalOwner1BalanceAfterConfirm = await ethers.provider.getBalance(
      owner1.address
    );
    //// replace ethers.provider with provide

    const expectedOwner1BalanceAfterConfirm =
      initialOwner1BalanceBeforeConfirm - gasUsedOwner1Confirm;
    const diffOwner1 =
      finalOwner1BalanceAfterConfirm - expectedOwner1BalanceAfterConfirm;
    const absDiffOwner1 = diffOwner1 < 0n ? -diffOwner1 : diffOwner1;
    expect(absDiffOwner1 <= GAS_MARGIN).to.be.true;

    // ---------------------------------------------------------------------
    // 8. Verify final recipient balances
    // ---------------------------------------------------------------------

    // 8A. Final ETH for owner2 and owner3
    const finalOwner2EthBalance = await ethers.provider.getBalance(
      owner2.address
    );
    const finalOwner3EthBalance = await ethers.provider.getBalance(
      owner3.address
    );
    //// replace ethers.provider with provide

    // We intended to give owner2 +0.01 ETH in the batch. But they also paid 'totalGasCostBatchTx' to send the batch
    const nominalEthGain = ethers.parseEther("0.01"); // The actual transferred amount to owner2
    const netExpectedGain = nominalEthGain - totalGasCostBatchTx; // Gains minus gas cost

    const actualOwner2Gain = finalOwner2EthBalance - initialOwner2EthBalance;
    const diffOwner2 = actualOwner2Gain - netExpectedGain;

    // A small margin is still a good idea:
    const bigMargin = ethers.parseEther("0.001"); // 0.001 ETH

    const absDiffOwner2 = diffOwner2 < 0n ? -diffOwner2 : diffOwner2;

    // Now do a plain boolean check:
    expect(absDiffOwner2 <= bigMargin).to.be.true;

    // We expected +0.005 ETH for owner3
    const expectedOwner3Gain = ethers.parseEther("0.005");
    const actualOwner3Gain = finalOwner3EthBalance - initialOwner3EthBalance;
    // Similarly, owner3 did not confirm, so they should have no gas cost here.
    expect(actualOwner3Gain).to.equal(expectedOwner3Gain);

    // 8B. Final ERC20 for owner2 and owner3
    const finalOwner2ERC20 = await simpleERC20.balanceOf(owner2.address);
    const finalOwner3ERC20 = await simpleERC20.balanceOf(owner3.address);

    // Owner2 got +10 tokens
    const expectedOwner2Erc20Gain = ethers.parseEther("10");
    expect(finalOwner2ERC20).to.equal(
      initialOwner2ERC20Balance + expectedOwner2Erc20Gain
    );

    // Owner3 got +20 tokens
    const expectedOwner3Erc20Gain = ethers.parseEther("20");
    expect(finalOwner3ERC20).to.equal(
      initialOwner3ERC20Balance + expectedOwner3Erc20Gain
    );

    // 8C. Final NFT ownership
    const finalNftOwner = await simpleERC721.ownerOf(nftTokenId);
    expect(finalNftOwner).to.equal(owner2.address);

    // Done! We verified:
    //  - ETH deposit
    //  - ERC20 deposit
    //  - NFT deposit
    //  - Single batch transfer
    //  - Confirm logs, execution logs, per-transfer logs
    //  - Final balances for ETH, ERC20, and NFT
  });

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
    const owner1ConfirmRemoveOwner3Tx = await multisigWallet.confirmTransaction(
      removeOwner3TxIndex
    );

    // Wait for confirm transaction to be mined
    const owner1ConfirmRemoveOwner3Receipt =
      await owner1ConfirmRemoveOwner3Tx.wait();

    // Fetch Owners
    const _twoOwners = await multisigWallet.getOwners();
    const twoOwnerCount = await multisigWallet.getOwnerCount();

    //Assert that owner1, owner2, owner3 and owner4 are the Owners
    expect(_twoOwners).to.eql([owner1.address, owner2.address]);
    expect(twoOwnerCount).to.eql(2n);
  });

  it("can receive and send ERC20 Tokens", async function () {
    // Deploy SimpleERC20 contract with initialSupply to owner1

    // Connect to owner1
    const SimpleERC20Factory = await ethers.getContractFactory("SimpleERC20");
    const initialSupply = ethers.parseEther("1000"); // 1000 tokens with 18 decimals

    // Deploy the contract connected as owner1
    const simpleERC20 = await SimpleERC20Factory.connect(owner1).deploy(
      initialSupply
    );

    await simpleERC20.waitForDeployment();

    // Now, simpleERC20 is deployed, and owner1 has initialSupply of tokens

    // Verify that owner1 has the tokens
    const owner1Balance = await simpleERC20.balanceOf(owner1.address);
    // Correct comparison using BigInt
    expect(owner1Balance > ethers.parseEther("100")).to.be.true;

    const initialOwner2Balance = await simpleERC20.balanceOf(owner2.address);

    // Now, let owner1 send some tokens to the multisigWallet
    const transferAmount = ethers.parseEther("100"); // Transfer 100 tokens

    // Owner1 sends tokens to multisigWallet
    const transferTx = await simpleERC20
      .connect(owner1)
      .transfer(multisigWallet.target, transferAmount);

    await transferTx.wait();

    // Verify that multisigWallet has received the tokens
    const multisigWalletBalance = await simpleERC20.balanceOf(
      multisigWallet.target
    );
    expect(multisigWalletBalance).to.equal(transferAmount);

    // Now, owner2 submits a transferERC20 transaction to transfer tokens from multisigWallet to owner2

    // Connect multisigWallet as owner2
    multisigWallet = multisigWallet.connect(owner2);

    // Owner2 calls transferERC20
    const submitTx = await multisigWallet.transferERC20(
      simpleERC20.target,
      owner2.address,
      transferAmount
    );

    const submitReceipt = await submitTx.wait();

    // Check emitted events for submit and confirm (since confirm is triggered automatically after submitting)
    const submitBlock = submitReceipt.blockNumber;

    // Filter for SubmitTransaction events
    const submitEvents = await multisigWallet.queryFilter(
      "SubmitTransaction",
      submitBlock,
      submitBlock
    );

    // Ensure that one SubmitTransaction event was emitted
    expect(submitEvents.length).to.equal(1);

    const submitEvent = submitEvents[0];

    // Now, encode the data as in the contract to compare
    const expectedData = simpleERC20.interface.encodeFunctionData("transfer", [
      owner2.address,
      transferAmount,
    ]);

    // Assert that the Event is emitted as expected
    expect(submitEvent.args._transactionType).to.equal(1n); // For ERC20
    expect(submitEvent.args.to).to.equal(owner2.address);
    expect(submitEvent.args.value).to.equal(0n);
    expect(submitEvent.args.tokenAddress).to.equal(simpleERC20.target);
    expect(submitEvent.args.amountOrTokenId).to.equal(transferAmount);
    expect(submitEvent.args.owner).to.equal(owner2.address);
    expect(submitEvent.args.data).to.be.equal(expectedData);

    // Confirm is triggered automatically after submitting
    // Check the ConfirmTransaction event
    const confirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      submitBlock,
      submitBlock
    );

    expect(confirmEvents.length).to.equal(1);

    const confirmEvent = confirmEvents[0];

    expect(confirmEvent.args.owner).to.equal(owner2.address);
    expect(confirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Now, owner1 needs to confirm the transaction

    // Connect multisigWallet as owner1
    multisigWallet = multisigWallet.connect(owner1);

    // Owner1 confirms the transaction
    const confirmTx = await multisigWallet.confirmTransaction(
      submitEvent.args.txIndex
    );

    const confirmReceipt = await confirmTx.wait();

    // This should trigger the execution as well

    // Check event logs for confirm and execution
    const confirmBlock = confirmReceipt.blockNumber;

    // Check the ConfirmTransaction event
    const owner1ConfirmEvents = await multisigWallet.queryFilter(
      "ConfirmTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(owner1ConfirmEvents.length).to.equal(1);

    const owner1ConfirmEvent = owner1ConfirmEvents[0];

    expect(owner1ConfirmEvent.args.owner).to.equal(owner1.address);
    expect(owner1ConfirmEvent.args.txIndex).to.equal(submitEvent.args.txIndex);

    // Check the ExecuteTransaction event
    const executeEvents = await multisigWallet.queryFilter(
      "ExecuteTransaction",
      confirmBlock,
      confirmBlock
    );

    expect(executeEvents.length).to.equal(1);

    const executeEvent = executeEvents[0];

    expect(executeEvent.args._transactionType).to.equal(1n); // ERC20
    expect(executeEvent.args.txIndex).to.equal(submitEvent.args.txIndex);
    expect(executeEvent.args.to).to.equal(owner2.address);
    expect(executeEvent.args.value).to.equal(0n);
    expect(executeEvent.args.tokenAddress).to.equal(simpleERC20.target);
    expect(executeEvent.args.amountOrTokenId).to.equal(transferAmount);
    expect(executeEvent.args.owner).to.equal(owner1.address);
    expect(executeEvent.args.data).to.equal(expectedData);

    // Now, verify that owner2 has received the tokens
    const owner2Balance = await simpleERC20.balanceOf(owner2.address);
    expect(owner2Balance).to.equal(initialOwner2Balance + transferAmount);

    // Also, verify that multisigWallet's balance has decreased
    const multisigWalletFinalBalance = await simpleERC20.balanceOf(
      multisigWallet.target
    );
    expect(multisigWalletFinalBalance).to.equal(0n);
  });

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
    const owner1ConfirmRemoveOwner2Tx = await multisigWallet.confirmTransaction(
      removeOwner2TxIndex
    );

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

  after(async function () {
    // get final owner balances
    const afterBalances = {
      owner1: await ethers.provider.getBalance(owner1.address),
      owner2: await ethers.provider.getBalance(owner2.address),
      owner3: await ethers.provider.getBalance(owner3.address),
      owner4: await ethers.provider.getBalance(owner4.address),
      owner5: await ethers.provider.getBalance(owner5.address),
    };

    // Log final balances and their differences
    console.log("\nFinal balances of owners:");
    console.log(
      "Owner1:",
      owner1.address,
      "| Balance (ETH):",
      ethers.formatEther(afterBalances.owner1)
    );
    console.log(
      "Owner2:",
      owner2.address,
      "| Balance (ETH):",
      ethers.formatEther(afterBalances.owner2)
    );
    console.log(
      "Owner3:",
      owner3.address,
      "| Balance (ETH):",
      ethers.formatEther(afterBalances.owner3)
    );
    console.log(
      "Owner4:",
      owner4.address,
      "| Balance (ETH):",
      ethers.formatEther(afterBalances.owner4)
    );
    console.log(
      "Owner5:",
      owner5.address,
      "| Balance (ETH):",
      ethers.formatEther(afterBalances.owner5)
    );

    console.log("\nBalance differences (ETH):");
    console.log(
      "Owner1:",
      ethers.formatEther(afterBalances.owner1 - beforeBalances.owner1)
    );
    console.log(
      "Owner2:",
      ethers.formatEther(afterBalances.owner2 - beforeBalances.owner2)
    );
    console.log(
      "Owner3:",
      ethers.formatEther(afterBalances.owner3 - beforeBalances.owner3)
    );
    console.log(
      "Owner4:",
      ethers.formatEther(afterBalances.owner4 - beforeBalances.owner4)
    );
    console.log(
      "Owner5:",
      ethers.formatEther(afterBalances.owner5 - beforeBalances.owner5)
    );
  });
});
