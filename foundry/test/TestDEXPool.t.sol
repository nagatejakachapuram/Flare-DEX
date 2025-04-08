// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/dex/DEXPool.sol";
import "..//mocks/mockERC20.sol";

contract TestDEXPool is Test {
    DEXPool public dexPool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;

    /// @dev Test setup
    function setUp() external {
        user = address(this);

        // Deploy mock tokens
        token0 = new MockERC20("Test_Token_1", "TT1", 18);
        token1 = new MockERC20("Test_Token_2", "TT2", 18);

        // Mint test tokens
        token0.mint(user, 10 ether);
        token1.mint(user, 10 ether);

        // Deploy pool
        dexPool = new DEXPool(address(token0), address(token1));

        // Approve tokens to be used by the pool
        token0.approve(address(dexPool), type(uint256).max);
        token1.approve(address(dexPool), type(uint256).max);
    }

    /// @dev Constructor parameter tests
    function testTokenAddressesAreCorrect() public {
        assertEq(address(dexPool.token0()), address(token0));
        assertEq(address(dexPool.token1()), address(token1));
    }

    function testInitialSqrtPriceX96IsCorrect() public {
        uint160 expectedSqrtPrice = uint160(2 ** 96);
        assertEq(
            dexPool.sqrtPriceX96(),
            expectedSqrtPrice,
            "Initial sqrtPriceX96 should be 2^96"
        );
    }

    function testInitialTickIsZero() public {
        int24 expectedTick = 0;
        assertEq(
            dexPool.currentTick(),
            expectedTick,
            "Initial tick should be zero"
        );
    }

    /// @dev Functionality Tests

    function testAddLiquidity() public {
        int24 tickLower = -60;
        int24 tickUpper = 60;
        uint128 liquidity = 100 ether;

        dexPool.addLiquidity(tickLower, tickUpper, liquidity);

        (int128 netLower, uint128 grossLower) = dexPool.ticks(tickLower);
        (int128 netUpper, uint128 grossUpper) = dexPool.ticks(tickUpper);

        assertEq(grossLower, liquidity);
        assertEq(grossUpper, liquidity);
        assertEq(netLower, int128(liquidity));
        assertEq(netUpper, -int128(liquidity));
    }

    function testRemoveLiquidity() public {
        int24 tickLower = -60;
        int24 tickUpper = 60;
        uint128 liquidity = 100 ether;

        // Add liquidity
        dexPool.addLiquidity(tickLower, tickUpper, liquidity);

        // Remove part of it
        uint128 liquidityToRemove = 50 ether;
        dexPool.removeLiquidity(tickLower, tickUpper, liquidityToRemove);

        (int128 netLower, uint128 grossLower) = dexPool.ticks(tickLower);
        (int128 netUpper, uint128 grossUpper) = dexPool.ticks(tickUpper);

        assertEq(grossLower, liquidity - liquidityToRemove); // 50 ether
        assertEq(grossUpper, liquidity - liquidityToRemove); // 50 ether
        assertEq(netLower, int128(liquidity)); // stays 100 ether
        assertEq(netUpper, -int128(liquidity)); // stays -100 ether
    }

    /// @dev Placeholder for swap test
    function testSimpleSwapV3() public {
        address fromToken = address(token0); // Assume swapping from token0 to token1
        uint256 amountIn = 1 ether;
        int24 lowerTick = -60;
        int24 upperTick = 60;

        // First, provide liquidity (needed for swap to work)
        uint128 liquidity = 100 ether;
        dexPool.addLiquidity(lowerTick, upperTick, liquidity);

        // Call the swap
        uint256 amountOut = dexPool.simpleSwapV3(
            fromToken,
            amountIn,
            lowerTick,
            upperTick
        );

        // Assertions
        assertGt(amountOut, 0, "Should receive some amount of output tokens");
    }
}
