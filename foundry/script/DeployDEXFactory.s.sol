// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../src/dex/DEXFactory.sol";
import "forge-std/Script.sol";

contract DeployDEXFactory is Script {
    function run() external {
        vm.startBroadcast();
        DEXFactory dexFactory = new DEXFactory();
        console.log("DEX Factory is deployed at: ", address(dexFactory));
        vm.stopBroadcast();
    }
}
