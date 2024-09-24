// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../lib/forge-std/src/Script.sol";
import "forge-std/console.sol"; // For logging

/**
 * @title SimpleEthTransfer
 * @notice This script sends 0.001 ETH from owner1 to owner2 on the Sepolia testnet.
 */
contract SimpleEthTransfer is Script {
    function run() public {
        // Start broadcasting the transaction using owner1's private key
        vm.startBroadcast(vm.envUint("SEPOLIA_PRIVATE_KEY_OWNER1"));

        // Define owner1 and owner2 addresses from environment variables
        address owner1 = vm.envAddress("OWNER1_ADDRESS");
        address owner2 = vm.envAddress("OWNER2_ADDRESS");

        // Log the chain ID and block number to confirm network
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        console.log("Running on chain ID:", chainId);
        console.log("Current block number:", block.number);

        // Log initial balances
        console.log("Initial owner1 balance:", owner1.balance);
        console.log("Initial owner2 balance:", owner2.balance);

        // Send 0.001 ETH from owner1 to owner2
        uint256 amountToSend = 0.001 ether;
        (bool success, ) = owner2.call{value: amountToSend}("");
        require(success, "ETH transfer failed");

        // Log final balances
        console.log("Final owner1 balance:", owner1.balance);
        console.log("Final owner2 balance:", owner2.balance);

        // Stop broadcasting the transaction
        vm.stopBroadcast();
    }
}
