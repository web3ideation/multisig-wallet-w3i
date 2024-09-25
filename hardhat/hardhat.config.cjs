require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("dotenv").config({ path: "../.env" });

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
  networks: {
    hardhat: {
      chainId: 31337,
      blockConfirmations: 1,
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
    timeout: 60000, // 60 seconds timeout
  },
};
