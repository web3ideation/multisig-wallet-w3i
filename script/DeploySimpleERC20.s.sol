// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SimpleERC20} from "../src/SimpleERC20.sol";

contract DeploySimpleERC20 is Script {
    function run() external returns (SimpleERC20) {
        vm.startBroadcast();

        SimpleERC20 token = new SimpleERC20(1000000 * 10 ** 18); // 1 million tokens

        vm.stopBroadcast();
        return token;
    }
}
