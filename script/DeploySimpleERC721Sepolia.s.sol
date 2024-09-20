// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {SimpleERC721} from "../src/SimpleERC721.sol";

contract DeploySimpleERC721 is Script {
    function run() external returns (SimpleERC721) {
        // Load private key from environment variable for security
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting the transaction
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the SimpleERC721 contract
        SimpleERC721 simpleERC721 = new SimpleERC721();

        // Stop broadcasting the transaction
        vm.stopBroadcast();

        return simpleERC721;
    }
}
