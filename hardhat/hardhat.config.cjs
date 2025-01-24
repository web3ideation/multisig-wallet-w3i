require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("dotenv").config({ path: "../.env" });
require("hardhat-gas-reporter");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.8.20",
      },
    ],
  },

  paths: {
    // sources: "../contracts", // Point to the shared contracts
    tests: "./test",
    scripts: "./scripts",
    cache: "./cache",
    artifacts: "./artifacts",
  },

  defaultNetwork: "hardhat",
  gasReporter: {
    enabled: true,
    currency: "ETH", // Report in ETH
    gasPrice: 6, // Adjust this to Sepolia's current gas price in gwei
    showTimeSpent: true, // Optional: show test execution time
  },
  networks: {
    hardhat: {
      chainId: 31337,
      blockConfirmations: 1,
      forking: {
        url: process.env.MAINNET_RPC_URL,
        blockNumber: 17296000, // higher ones don't is work, even tho the execution layer block height is already at 21689275...
      },
      gasPrice: 50000000000,
    },
    localhost: {
      chainId: 31337,
      blockConfirmations: 1,
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL, // e.g., Infura or Alchemy URL
      accounts: [process.env.OWNER1_PRIVATE_KEY], // Private key of owner1
    },
  },

  mocha: {
    timeout: 600000, // 10 minutes timeout
  },
};
