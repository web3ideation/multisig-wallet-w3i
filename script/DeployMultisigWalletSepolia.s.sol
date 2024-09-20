// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployMultisigWallet is Script {
    function run() external returns (MultisigWallet) {
        // Load private key from environment variable for security
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting the transaction
        vm.startBroadcast(deployerPrivateKey);

        // Specify the multisig owners
        address[] memory owners = new address[](1);
        owners[0] = 0xE8dF60a93b2B328397a8CBf73f0d732aaa11e33D;

        MultisigWallet multisigWallet = new MultisigWallet(owners);

        vm.stopBroadcast();
        return multisigWallet;
    }
}

// to deploy run: forge script script/DeployMultisigWalletSepolia.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify