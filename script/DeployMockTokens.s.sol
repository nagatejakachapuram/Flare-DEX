// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/mocks/MockERC20.sol";

contract DeployMockTokens is Script {
    function run() public {
        // Deploy the MockERC20 token (WC2FLR & testUSD)
        vm.startBroadcast();

        MockERC20 wc2flr = new MockERC20("Wrapped C2FLR", "WC2FLR", 18);
        MockERC20 testUSD = new MockERC20("Test USD", "tUSD", 18);

        console.log("WC2FLR deployed at:", address(wc2flr));
        console.log("Test USD deployed at:", address(testUSD));

        // Mint tokens to your wallet
        address wallet = 0x14650D0420cFf23c5d9300Db8483aDD0D6feb2a1;
        wc2flr.mint(wallet, 1000000 * 10 ** 18); // Mint 1 million WC2FLR tokens
        testUSD.mint(wallet, 1000000 * 10 ** 18); // Mint 1 million Test USD tokens

        console.log("Minted WC2FLR and Test USD tokens to:", wallet);

        vm.stopBroadcast();
    }
}
