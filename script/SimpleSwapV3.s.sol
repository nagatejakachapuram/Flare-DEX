// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/dex/DEXPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleSwapV3 is Script {
    address constant POOL = 0x8c847Ad2bAfA13a50fc319A6d7389405666dbe72;
    address constant WC2FLR = 0xC67DCE33D7A8efA5FfEB961899C73fe01bCe9273;
    address constant testUSD = 0x6623C0BB56aDb150dC9C6BdB8682521354c2BF73;

    int24 constant LOWER_TICK = -600;
    int24 constant UPPER_TICK = 600;
    uint256 constant AMOUNT_IN = 10 * 1e18; // Swap 10 WC2FLR tokens (10 * 10^18)

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        DEXPool pool = DEXPool(POOL);

        // Hardcoded token selection for swap (WC2FLR -> testUSD)
        address fromToken = WC2FLR;

        // Validate the fromToken is either WC2FLR or testUSD
        require(
            fromToken == WC2FLR || fromToken == testUSD,
            "Invalid fromToken"
        );

        // Approve the pool to spend the input token
        IERC20(fromToken).approve(POOL, AMOUNT_IN);

        // Execute the swap
        uint256 amountOut = pool.simpleSwapV3(
            fromToken,
            AMOUNT_IN,
            LOWER_TICK,
            UPPER_TICK
        );

        console.log("Swap completed. Output amount:", amountOut);

        vm.stopBroadcast();
    }
}
