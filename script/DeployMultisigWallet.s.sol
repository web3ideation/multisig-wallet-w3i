// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Script} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployMultisigWallet is Script {
    function run() external returns (MultisigWallet) {
        vm.startBroadcast();

        address[] memory owners = new address[](5);
        owners[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        owners[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        owners[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        owners[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        owners[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

        MultisigWallet multisigWallet = new MultisigWallet(owners);

        vm.stopBroadcast();
        return multisigWallet;
    }
}
