// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/dex/DEXPool.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AddLiquidity is Script {
    address constant POOL = 0x8c847Ad2bAfA13a50fc319A6d7389405666dbe72;
    address constant WC2FLR = 0xC67DCE33D7A8efA5FfEB961899C73fe01bCe9273;
    address constant testUSD = 0x6623C0BB56aDb150dC9C6BdB8682521354c2BF73;

    int24 constant LOWER_TICK = -600;
    int24 constant UPPER_TICK = 600;
    uint128 constant LIQUIDITY = 1_000_000;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        DEXPool pool = DEXPool(POOL);

        address token0 = address(pool.token0());
        address token1 = address(pool.token1());

        IERC20(token0).approve(POOL, type(uint256).max);
        IERC20(token1).approve(POOL, type(uint256).max);

        pool.addLiquidity(LOWER_TICK, UPPER_TICK, LIQUIDITY);

        console.log("Liquidity added to the pool.");

        vm.stopBroadcast();
    }
}
