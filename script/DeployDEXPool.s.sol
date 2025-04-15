// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/dex/DEXFactory.sol";

contract DeployDEXPool is Script {
    address constant FACTORY = 0x589a43d979dA679E9D8fc0fa72C31db81Cf91afC;
    address constant WC2FLR = 0xC67DCE33D7A8efA5FfEB961899C73fe01bCe9273;
    address constant testUSD = 0x6623C0BB56aDb150dC9C6BdB8682521354c2BF73;
    address constant ETH = 0xf3187D2115171708fca10f1A11c522172d7Ec2d5;
    address constant testXLM = 0xCf5B4553Ea9C20DebAb75EC0B735DF6315684285;
    address ftsoV2Address = 0xBF55AFB5d543db03f55852B02973B24345EAd1e1;

    function run() external {
        vm.startBroadcast();

        DEXFactory factory = DEXFactory(FACTORY);
        address pool = factory.createPool(WC2FLR, testUSD, ftsoV2Address);

        console.log("DEX Pool deployed at:", pool);

        vm.stopBroadcast();
    }
}
