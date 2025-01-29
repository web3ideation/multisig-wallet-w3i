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
        owners[0] = 0xd5A4Ed9d14bc273ce995B4E7E8fa0a21E59F8F3b; // Stefan
        owners[1] = 0xBae2957B8c6CC7D39b7fDF5e82Cf8C467B86Be40; // Wolfi
        owners[2] = 0x5a7c04218942c1c9baED35289A9b3eDfEd6F216F; // Niklas

        MultisigWallet multisigWallet = new MultisigWallet(owners);

        vm.stopBroadcast();
        return multisigWallet;
    }
}

// to deploy run: source .env AND forge script script/DeployMultisigWalletMainnet.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify --account defaultKey --sender 0xe8df60a93b2b328397a8cbf73f0d732aaa11e33d
