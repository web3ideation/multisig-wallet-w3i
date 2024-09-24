// scripts/staging-test-sepolia.js

const { ethers } = require("hardhat");
require("dotenv").config({ path: "../.env" });

async function main() {
  // Retrieve environment variables
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

  // Initialize provider for Sepolia
  const provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC_URL);

  // Initialize signer (owner1) using the private key
  const owner1 = new ethers.Wallet(OWNER1_PRIVATE_KEY, provider);

  // Verify that owner1Address matches the signer's address
  if (owner1.address.toLowerCase() !== OWNER1_ADDRESS.toLowerCase()) {
    throw new Error(
      "Mismatch between owner1 signer and OWNER1_ADDRESS environment variable"
    );
  }

  console.log(`Connected as Owner1: ${owner1.address}`);

  // Connect to the MultisigWallet contract
  const MultisigWallet = await ethers.getContractAt(
    "MultisigWallet",
    MULTISIGWALLET_ADDRESS,
    owner1
  );

  // Initiate addOwner2
  console.log("Initiating addOwner2 transaction...");
  const addOwner2Tx = await MultisigWallet.addOwner(OWNER2_ADDRESS);
  console.log("addOwner2 Transaction Hash:", addOwner2Tx.hash);

  // Wait for withdrawal transaction to be mined
  const addOwner2Receipt = await addOwner2Tx.wait();
  console.log(
    `addOwner2 Transaction Confirmed in Block: ${addOwner2Receipt.blockNumber}`
  );

  // Track gas cost for withdrawal transaction
  const gasUsedAddOwner2 = addOwner2Receipt.gasUsed.mul(
    addOwner2Receipt.effectiveGasPrice
  );
  console.log(
    `Gas Used for addOwner2 (in ETH): ${ethers.utils.formatEther(
      gasUsedAddOwner2
    )} ETH`
  );

  //check success

  const twoOwners = await MultisigWallet.getOwners();

  if (twoOwners.eq([OWNER1_ADDRESS, OWNER2_ADDRESS])) {
    console.log("Pass: addOwner2 correct");
  } else {
    console.log("Fail: addOwner2 failed");
    console.log(`Actual Owners: ${twoOwners}`);
  }

  // Define deposit amount
  const depositAmount = ethers.utils.parseEther("0.01"); // 0.01 ETH

  // Fetch initial balances
  const initialOwner1Balance = await provider.getBalance(owner1.address);
  const initialWalletBalance = await provider.getBalance(
    MULTISIGWALLET_ADDRESS
  );

  console.log(
    `Initial Owner1 Balance: ${ethers.utils.formatEther(
      initialOwner1Balance
    )} ETH`
  );
  console.log(
    `Initial Wallet Balance: ${ethers.utils.formatEther(
      initialWalletBalance
    )} ETH`
  );

  if (initialOwner1Balance.lt(depositAmount)) {
    throw new Error("Insufficient funds for deposit");
  }

  // Send deposit transaction
  console.log("Sending deposit transaction...");
  const depositTx = await owner1.sendTransaction({
    to: MULTISIGWALLET_ADDRESS,
    value: depositAmount,
  });

  console.log("Deposit Transaction Hash:", depositTx.hash);

  // Wait for deposit transaction to be mined
  const depositReceipt = await depositTx.wait();
  console.log(
    `Deposit Transaction Confirmed in Block: ${depositReceipt.blockNumber}`
  );

  // Track gas cost for deposit transaction
  const gasUsedDeposit = depositReceipt.gasUsed.mul(
    depositReceipt.effectiveGasPrice
  );
  console.log(
    `Gas Used for Deposit (in ETH): ${ethers.utils.formatEther(
      gasUsedDeposit
    )} ETH`
  );

  // Fetch wallet balance after deposit
  const walletBalanceAfterDeposit = await provider.getBalance(
    MULTISIGWALLET_ADDRESS
  );
  console.log(
    `Wallet Balance After Deposit: ${ethers.utils.formatEther(
      walletBalanceAfterDeposit
    )} ETH`
  );

  // Assert deposit amount
  if (walletBalanceAfterDeposit.eq(initialWalletBalance.add(depositAmount))) {
    console.log("Pass: Deposit amount correct");
  } else {
    console.log("Fail: Deposit amount incorrect");
    console.log(
      `Expected Wallet Balance: ${ethers.utils.formatEther(
        initialWalletBalance.add(depositAmount)
      )} ETH`
    );
    console.log(
      `Actual Wallet Balance: ${ethers.utils.formatEther(
        walletBalanceAfterDeposit
      )} ETH`
    );
  }

  // Initiate withdrawal
  console.log("Initiating withdrawal transaction...");
  const withdrawalTx = await MultisigWallet.sendETH(
    OWNER1_ADDRESS,
    walletBalanceAfterDeposit
  );
  console.log("Withdrawal Transaction Hash:", withdrawalTx.hash);

  // Wait for withdrawal transaction to be mined
  const withdrawalReceipt = await withdrawalTx.wait();
  console.log(
    `Withdrawal Transaction Confirmed in Block: ${withdrawalReceipt.blockNumber}`
  );

  // Track gas cost for withdrawal transaction
  const gasUsedWithdrawal = withdrawalReceipt.gasUsed.mul(
    withdrawalReceipt.effectiveGasPrice
  );
  console.log(
    `Gas Used for Withdrawal (in ETH): ${ethers.utils.formatEther(
      gasUsedWithdrawal
    )} ETH`
  );

  // Fetch final wallet balance
  const finalWalletBalance = await provider.getBalance(MULTISIGWALLET_ADDRESS);
  console.log(
    `Final Wallet Balance: ${ethers.utils.formatEther(finalWalletBalance)} ETH`
  );

  if (finalWalletBalance.eq(0)) {
    console.log("Pass: Withdrawal successful, wallet balance is zero");
  } else {
    console.log("Fail: Withdrawal failed, wallet balance is not zero");
  }

  // Fetch final owner1 balance
  const finalOwner1Balance = await provider.getBalance(owner1.address);
  console.log(
    `Final Owner1 Balance: ${ethers.utils.formatEther(finalOwner1Balance)} ETH`
  );

  // Calculate the expected final balance of owner1 after gas costs
  const expectedFinalBalance = initialOwner1Balance
    .sub(gasUsedDeposit) // Subtract gas used in deposit
    .sub(gasUsedWithdrawal); // Subtract gas used in withdrawal

  console.log(
    `Expected Final Owner1 Balance after Gas Costs: ${ethers.utils.formatEther(
      expectedFinalBalance
    )} ETH`
  );

  // Since gas costs are involved, allow a small margin for discrepancies
  const balanceDifference = finalOwner1Balance.sub(expectedFinalBalance).abs();
  const margin = ethers.utils.parseEther("0.001"); // 0.001 ETH margin

  if (balanceDifference.lte(margin)) {
    console.log("Pass: Owner1 received the correct balance after gas costs");
  } else {
    console.log(
      "Fail: Owner1 did not receive the correct balance after gas costs"
    );
    console.log(
      `Actual Owner1 Balance: ${ethers.utils.formatEther(
        finalOwner1Balance
      )} ETH`
    );
    console.log(
      `Expected Owner1 Balance: ${ethers.utils.formatEther(
        expectedFinalBalance
      )} ETH`
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
