// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/dex/DEXPool.sol";

contract RemoveLiquidity is Script {
    address constant POOL = 0x8c847Ad2bAfA13a50fc319A6d7389405666dbe72;
    int24 public lowerTick;
    int24 public upperTick;

    uint256 constant LIQUIDITY = 1e18;

    function run() external {
        vm.startBroadcast();

        DEXPool(POOL).removeLiquidity(lowerTick, upperTick, uint128(LIQUIDITY));

        vm.stopBroadcast();
    }
}
