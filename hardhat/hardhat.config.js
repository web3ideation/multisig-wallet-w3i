require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("@nomiclabs/hardhat-ethers"); // Ensure this is included
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

  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL, // e.g., Infura or Alchemy URL
      accounts: [process.env.OWNER1_PRIVATE_KEY], // Private key of owner1
    },
  },
};
