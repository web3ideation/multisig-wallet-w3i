// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployMultisigWallet is Script {
    function run() external returns (MultisigWallet) {
        vm.startBroadcast();

        MultisigWallet multisigWallet = new MultisigWallet();

        vm.stopBroadcast();
        return multisigWallet;
    }
}
