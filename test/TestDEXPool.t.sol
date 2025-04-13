// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/dex/DEXPool.sol";
import "../src/mocks/mockERC20.sol";

contract TestDEXPool is Test {
    DEXPool public dexPool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    IFTSOOracle oracle;
    address oracleAddress;

    int24 lowerTick;
    int24 upperTick;
    uint128 liquidityDelta;
    LPToken public lpTokenInstance;

    function setUp() external {
        user = address(this);

        // Deploy mock tokens
        token0 = new MockERC20("Test_Token_1", "TT1", 18);
        token1 = new MockERC20("Test_Token_2", "TT2", 18);

        // Deploy LPToken contract
        lpTokenInstance = new LPToken("Liquidity Provider Token", "LPT");

        // Deploy DEXPool contract
        dexPool = new DEXPool(
            address(token0),
            address(token1),
            address(lpTokenInstance)
        );

        // Mint tokens to the user
        token0.mint(user, 10000000000000000000); // 10^19
        token1.mint(user, 10000000000000000000); // 10^19

        // Approve DEXPool to spend user's tokens
        token0.approve(address(dexPool), 10000000000000000000); // 10^19
        token1.approve(address(dexPool), 10000000000000000000); // 10^19

        // Initialize missing variables
        lowerTick = -60;
        upperTick = 60;
        liquidityDelta = 1000 ether;
    }

    function testTokenAddressesAreCorrect() public view {
        assertEq(
            address(dexPool.token0()),
            address(token0),
            "Token0 address is incorrect"
        );
        assertEq(
            address(dexPool.token1()),
            address(token1),
            "Token1 address is incorrect"
        );
    }

    function testInitialSqrtPriceX96IsCorrect() public view {
        uint160 expectedSqrtPrice = uint160(2 ** 96);
        assertEq(
            dexPool.sqrtPriceX96(),
            expectedSqrtPrice,
            "Initial sqrtPriceX96 should be 2^96"
        );
    }

    function testInitialTickIsZero() public view {
        int24 expectedTick = 0;
        assertEq(
            dexPool.currentTick(),
            expectedTick,
            "Initial tick should be zero"
        );
    }

    function testAddLiquidity() public {
        uint256 initialBalanceToken0 = token0.balanceOf(user);
        uint256 initialBalanceToken1 = token1.balanceOf(user);

        // Call addLiquidity with valid parameters
        dexPool.addLiquidity(lowerTick, upperTick, liquidityDelta);

        // Check that the liquidity was added and tokens were transferred
        uint256 finalBalanceToken0 = token0.balanceOf(user);
        uint256 finalBalanceToken1 = token1.balanceOf(user);

        // Calculate expected token amounts based on the test parameters
        uint256 expectedAmount0;
        uint256 expectedAmount1;

        uint160 sqrtA = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPrice = dexPool.sqrtPriceX96(); 

        (expectedAmount0, expectedAmount1) = dexPool._calculateAmounts(
            sqrtPrice,
            sqrtA,
            sqrtB,
            liquidityDelta
        );

        // Ensure tokens were deducted correctly
        assertEq(
            initialBalanceToken0 - finalBalanceToken0,
            expectedAmount0,
            "Token0 balance after addLiquidity mismatch"
        );
        assertEq(
            initialBalanceToken1 - finalBalanceToken1,
            expectedAmount1,
            "Token1 balance after addLiquidity mismatch"
        );

        // Ensure liquidity state in DEXPool has been updated
        uint256 liquidityInPool = dexPool.liquidity();
        assertEq(
            liquidityInPool,
            liquidityDelta,
            "Liquidity in pool mismatch after addLiquidity"
        );
    }

    function testRemoveLiquidity() public {
        // Simulate user address
        address userAddress = address(0xABCD);

        // Give user enough tokens
        deal(address(token0), userAddress, 1e24);
        deal(address(token1), userAddress, 1e24);

        // User approves tokens to dexPool
        vm.startPrank(userAddress);
        token0.approve(address(dexPool), type(uint256).max);
        token1.approve(address(dexPool), type(uint256).max);
        vm.stopPrank();

        // Add liquidity as the user
        vm.startPrank(userAddress);
        dexPool.addLiquidity(lowerTick, upperTick, liquidityDelta);
        vm.stopPrank();

        // Capture state *after* addLiquidity
        uint256 initialReserve0 = dexPool.reserve0();
        uint256 initialReserve1 = dexPool.reserve1();
        uint256 initialTotalLPSupply = lpTokenInstance.totalSupply(); 
        uint256 initialLPBalance = lpTokenInstance.balanceOf(userAddress);

        // Log the captured state
        console.log("After addLiquidity:");
        console.log("  initialReserve0:", initialReserve0);
        console.log("  initialReserve1:", initialReserve1);
        console.log("  initialTotalLPSupply:", initialTotalLPSupply);
        console.log("  initialLPBalance:", initialLPBalance);

        // Capture initial balances
        uint256 initialBalanceToken0 = token0.balanceOf(userAddress);
        uint256 initialBalanceToken1 = token1.balanceOf(userAddress);

        // Capture final balances *after* removeLiquidity
        uint256 finalBalanceToken0 = token0.balanceOf(userAddress);
        uint256 finalBalanceToken1 = token1.balanceOf(userAddress);
        uint256 finalLPBalance = lpTokenInstance.balanceOf(userAddress);

        // Log the final state
        console.log("After removeLiquidity:");
        console.log("  finalBalanceToken0:", finalBalanceToken0);
        console.log("  finalBalanceToken1:", finalBalanceToken1);
        console.log("  finalLPBalance:", finalLPBalance);
        console.log("  DEXPool reserve0:", dexPool.reserve0());
        console.log("  DEXPool reserve1:", dexPool.reserve1());
        console.log("  LPToken totalSupply:", lpTokenInstance.totalSupply());

        // Expected token calculations
        uint160 sqrtA = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPrice = dexPool.sqrtPriceX96();

        (uint256 expectedAmount0, uint256 expectedAmount1) = dexPool
            ._calculateAmounts(sqrtPrice, sqrtA, sqrtB, liquidityDelta);
        

        // Assert token balances
        assertEq(
            finalBalanceToken0 - initialBalanceToken0,
            expectedAmount0,
            "Token0 balance after removeLiquidity mismatch"
        );
        assertEq(
            finalBalanceToken1 - initialBalanceToken1,
            expectedAmount1,
            "Token1 balance after removeLiquidity mismatch"
        );
        

        // Assert LP tokens burned.  Use the captured initialTotalLPSupply
        uint256 expectedLpTokens = ((expectedAmount0 + expectedAmount1) *
            initialLPBalance) / initialTotalLPSupply;

        assertEq(
            initialLPBalance - finalLPBalance,
            expectedLpTokens,
            "LP Token balance after removeLiquidity mismatch"
        );
    }

    function testRemoveLiquidityWithInsufficientLiquidity() public {
        // Trying to remove liquidity before adding it should fail
        vm.expectRevert("Insufficient position liquidity");
        dexPool.removeLiquidity(lowerTick, upperTick, liquidityDelta);
    }

    function testAddLiquidityWithInvalidParams() public {
        // Adding liquidity with invalid parameters (e.g., invalid tick range)
        vm.expectRevert("Invalid params");
        dexPool.addLiquidity(upperTick, lowerTick, liquidityDelta);
    }

    function testSimpleSwapV3() public {
        // Mint tokens if needed
        token0.mint(user, 1e18);
        token1.mint(user, 1e18);

        // Add initial liquidity
        dexPool.addLiquidity(lowerTick, upperTick, liquidityDelta);

        // Get initial balances
        uint256 initialBalanceUserToken0 = token0.balanceOf(user);
        uint256 initialBalancePoolToken0 = token0.balanceOf(address(dexPool));
        uint256 initialBalanceUserToken1 = token1.balanceOf(user);
        uint256 initialBalancePoolToken1 = token1.balanceOf(address(dexPool));

        // Ensure liquidity was added
        (uint256 reserve0, uint256 reserve1) = dexPool.getReserves();
        assertGt(reserve0, 0, "Reserve of token0 should be greater than 0");
        assertGt(reserve1, 0, "Reserve of token1 should be greater than 0");

        // Define swap amount
        uint256 swapAmount = 1e18; 

        // Perform the swap: Swap token0 for token1
        dexPool.simpleSwapV3(address(token0), swapAmount, lowerTick, upperTick);

        // Get final balances
        uint256 finalBalanceUserToken0 = token0.balanceOf(user);
        uint256 finalBalancePoolToken0 = token0.balanceOf(address(dexPool));
        uint256 finalBalanceUserToken1 = token1.balanceOf(user);
        uint256 finalBalancePoolToken1 = token1.balanceOf(address(dexPool));

        // Assert that user's token0 balance decreased
        assertLt(
            finalBalanceUserToken0,
            initialBalanceUserToken0,
            "User token0 balance should decrease"
        );
        // Assert that pool's token0 balance increased
        assertGt(
            finalBalancePoolToken0,
            initialBalancePoolToken0,
            "Pool token0 balance should increase"
        );
        // Assert that user's token1 balance increased
        assertGt(
            finalBalanceUserToken1,
            initialBalanceUserToken1,
            "User token1 balance should increase"
        );
        // Assert that pool's token1 balance decreased.
        assertLt(
            finalBalancePoolToken1,
            initialBalancePoolToken1,
            "Pool token1 balance should decrease"
        );
    }

    function testWithNoLiquidity() public {
        address fromToken = address(token0);
        uint256 amountIn = 1000;
        int24 _lowerTick = -60000;
        int24 _upperTick = 60000;

        (uint256 reserve0, uint256 reserve1) = dexPool.getReserves();
        assertEq(reserve0, 0, "Token0 reserve should be zero");
        assertEq(reserve1, 0, "Token1 reserve should be zero");

        vm.expectRevert("Insufficient output");
        dexPool.simpleSwapV3(fromToken, amountIn, _lowerTick, _upperTick);
    }

    function testIncorrectTokens() public {
        MockERC20 fakeToken = new MockERC20("LIQUID POOL TOKEN", "LPT", 18);
        uint256 amountIn = 1000;

        vm.expectRevert("Invalid Token");
        dexPool.simpleSwapV3(address(fakeToken), amountIn, -60000, 60000);
    }

    function testInvalidAmountAddingOfLiquidity() public {
        int24 _lowerTick = -60000;
        int24 _upperTick = 60000;
        uint128 _liquidityDelta = 0;

        vm.expectRevert("Invalid params");
        dexPool.addLiquidity(_lowerTick, _upperTick, _liquidityDelta);
    }

    function testInvalidTickRangeAddingLiquidity() public {
        int24 _lowerTick = 100;
        int24 _upperTick = -100;
        uint128 _liquidityDelta = 1000;

        vm.expectRevert("Invalid params");
        dexPool.addLiquidity(_lowerTick, _upperTick, _liquidityDelta);
    }

    function testCalculateAmountsAlternative() public view {
        uint128 liquidity = 1000000000000000000000; // 1000 ether
        uint160 sqrtA = 79228162514264337593543950336 / 2; // ~sqrt(price 0.5)
        uint160 sqrtB = 79228162514264337593543950336 * 2; // ~sqrt(price 2)
        uint160 sqrtCurrentPrice = 79228162514264337593543950336; // ~sqrt(price 1)

        (uint256 amount0, uint256 amount1) = dexPool._calculateAmounts(
            sqrtCurrentPrice,
            sqrtA,
            sqrtB,
            liquidity
        );

        uint256 expectedAmount0 = (uint256(liquidity) *
            (uint256(sqrtB) - uint256(sqrtCurrentPrice))) / (2 ** 96);
        uint256 expectedAmount1 = (uint256(liquidity) *
            (uint256(sqrtCurrentPrice) - uint256(sqrtA))) / (2 ** 96);

        assertEq(amount0, expectedAmount0, "amount0 mismatch");
        assertEq(amount1, expectedAmount1, "amount1 mismatch");
    }

    // Additional test cases

    function testAddLiquidity_ZeroLiquidity() public {
        vm.expectRevert("Invalid params");
        dexPool.addLiquidity(lowerTick, upperTick, 0);
    }

    function testRemoveLiquidity_ZeroLiquidity() public {
        vm.expectRevert("Invalid params");
        dexPool.removeLiquidity(lowerTick, upperTick, 0);
    }

    function testRemoveLiquidity_MoreThanOwned() public {
        dexPool.addLiquidity(lowerTick, upperTick, liquidityDelta);
        vm.expectRevert("Insufficient position liquidity");
        dexPool.removeLiquidity(lowerTick, upperTick, liquidityDelta + 1);
    }

    function testSimpleSwapV3_NoLiquidity() public {
        vm.expectRevert("Insufficient output");
        dexPool.simpleSwapV3(address(token0), 1 ether, lowerTick, upperTick);
    }

    function testGetReserves() public {
        (uint256 reserve0, uint256 reserve1) = dexPool.getReserves();
        assertEq(reserve0, 0, "Initial reserve0 should be 0");
        assertEq(reserve1, 0, "Initial reserve1 should be 0");

        dexPool.addLiquidity(lowerTick, upperTick, liquidityDelta);
        (reserve0, reserve1) = dexPool.getReserves();
        assertGt(
            reserve0,
            0,
            "reserve0 should be greater than 0 after adding liquidity"
        );
        assertGt(
            reserve1,
            0,
            "reserve1 should be greater than 0 after adding liquidity"
        );
    }

    function testGetLiquidityForUser() public {
        assertEq(
            dexPool.getLiquidityForUser(user, lowerTick, upperTick),
            0,
            "Initial liquidity for user should be 0"
        );
        dexPool.addLiquidity(lowerTick, upperTick, liquidityDelta);
        assertEq(
            dexPool.getLiquidityForUser(user, lowerTick, upperTick),
            liquidityDelta,
            "Liquidity for user should match added liquidity"
        );
    }
}
