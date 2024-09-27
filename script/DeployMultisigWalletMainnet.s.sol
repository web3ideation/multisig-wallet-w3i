// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployMultisigWalletMainnet is Script {
    function run() external returns (MultisigWallet) {
        // Load private key from environment variable for security
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        // Start broadcasting the transaction
        vm.startBroadcast(deployerPrivateKey);

        // Specify the multisig owners
        address[] memory owners = new address[](3);
        owners[0] = 0x0000000000000000000000000000000000000000; // Stefan
        owners[1] = 0x759941ECB2B2961566C94e4dB53ae3EeC35F980c; // Wolfi
        owners[2] = 0x0000000000000000000000000000000000000000; // Niklas

        MultisigWallet multisigWallet = new MultisigWallet(owners);

        vm.stopBroadcast();
        return multisigWallet;
    }
}

// to deploy run: source .env AND forge script script/DeployMultisigWalletMainnet.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify
