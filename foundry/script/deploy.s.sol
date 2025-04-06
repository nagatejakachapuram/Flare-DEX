//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {FTSOOracle} from "../src/FTSOOracle.sol";
import {ContractRegistry} from "@flare-smart-contracts/ContractRegistry.sol";

contract deploy is Script {
    bytes21[] public feedIds = [
        bytes21(0x01464c522f55534400000000000000000000000000),
        bytes21(0x014254432f55534400000000000000000000000000),
        bytes21(0x014554482f55534400000000000000000000000000)
    ];

    function run() external returns (FTSOOracle) {
        string memory key = vm.envString("PRIVATE_KEY");
        console2.log("Loaded PRIVATE_KEY:", key);
        vm.startBroadcast();

        FTSOOracle deployedFtsoOracle = new FTSOOracle(feedIds);
        address ftsoOracleAddress = address(deployedFtsoOracle);

        console.log("FTSOOracle deployed to: ", ftsoOracleAddress);
        vm.stopBroadcast();

        return deployedFtsoOracle;
    }
}
