// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployMultisigWalletMainnet is Script {
    function run() external returns (MultisigWallet) {
        // Start broadcasting the transaction
        vm.startBroadcast();

        // Specify the multisig owners
        address[] memory owners = new address[](3);
        owners[0] = 0x0000000000000000000000000000000000000000; // Stefan
        owners[1] = 0x759941ECB2B2961566C94e4dB53ae3EeC35F980c; // Wolfi
        owners[2] = 0x5a7c04218942c1c9baED35289A9b3eDfEd6F216F; // Niklas

        MultisigWallet multisigWallet = new MultisigWallet(owners);

        vm.stopBroadcast();
        return multisigWallet;
    }
}

// to deploy run: source .env AND forge script script/DeployMultisigWalletMainnet.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify --account defaultKey --sender 0xe8df60a93b2b328397a8cbf73f0d732aaa11e33d
