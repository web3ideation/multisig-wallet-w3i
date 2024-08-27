// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {SimpleERC721} from "../src/SimpleERC721.sol";

contract DeploySimpleERC721 is Script {
    function run() external returns (SimpleERC721) {
        vm.startBroadcast();
        SimpleERC721 simpleERC721 = new SimpleERC721();
        vm.stopBroadcast();
        return simpleERC721;
    }
}
