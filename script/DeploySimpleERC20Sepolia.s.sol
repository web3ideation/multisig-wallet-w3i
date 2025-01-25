// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SimpleERC20} from "../src/SimpleERC20.sol";

contract DeploySimpleERC20 is Script {
    function run() external returns (SimpleERC20) {
        // Load private key from environment variable for security
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting the transaction
        vm.startBroadcast(deployerPrivateKey);

        // Deploy SimpleERC20 with an initial supply of 1000 tokens
        SimpleERC20 token = new SimpleERC20(1000 * 10 ** 18);

        // Stop broadcasting the transaction
        vm.stopBroadcast();

        return token;
    }
}
