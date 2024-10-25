// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployMultisigWalletSepolia is Script {
    function run() external returns (MultisigWallet) {
        // Load private key from environment variable for security
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting the transaction
        vm.startBroadcast(deployerPrivateKey);

        // Specify the multisig owners
        address[] memory owners = new address[](3);
        owners[0] = 0xE8dF60a93b2B328397a8CBf73f0d732aaa11e33D;
        owners[1] = 0x8a200122f666af83aF2D4f425aC7A35fa5491ca7;
        owners[2] = 0xEdC9b2CA57635C98064988A3D3Ad24f9Bb9ADc6A;

        MultisigWallet multisigWallet = new MultisigWallet(owners);

        vm.stopBroadcast();
        return multisigWallet;
    }
}

// to deploy run: source .env AND forge script script/DeployMultisigWalletSepolia.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify
