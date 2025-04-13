// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./FTSOOracle.sol";
import "./LPToken.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {console} from "forge-std/console.sol";

/// @title DEXPool - A Simplified Decentralized Exchange Pool
/// @notice Implements a simplified decentralized exchange pool similar to Uniswap V3.
contract DEXPool is ReentrancyGuard {
    using LiquidityAmounts for uint128;
    using SafeMath for uint256;

    // =========================================================================
    // IMMUTABLE STATE VARIABLES
    // =========================================================================

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    LPToken public immutable lpToken;

    IFTSOOracle public immutable ftsoOracle;

    // =========================================================================
    // MUTABLE STATE VARIABLES
    // =========================================================================

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalReserves;

    uint160 public sqrtPriceX96;
    int24 public currentTick;
    uint128 public liquidity;
    uint128 constant MIN_LIQUIDITY = 1 ether;

    // =========================================================================
    // STRUCTS & MAPPINGS
    // =========================================================================

    /// @notice Represents a user's position within a specific tick range.
    struct Position {
        uint128 liquidity;
        uint256 feeGrowthInside0Last;
        uint256 feeGrowthInside1Last;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
    }

    mapping(address => mapping(int24 => mapping(int24 => Position)))
        public positions;

    // =========================================================================
    // EVENTS
    // =========================================================================

    event LiquidityAdded(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokensMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokensBurned
    );
    event Swap(
        address indexed sender,
        uint256 indexed amountIn,
        uint256 indexed amountOut,
        bool zeroForOne
    );

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    /// @param _token0 Address of the first token.
    /// @param _token1 Address of the second token.
    /// @param _oracleAddress Address of the FTSO oracle.
    constructor(address _token0, address _token1, address _oracleAddress) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        ftsoOracle = IFTSOOracle(_oracleAddress);
        sqrtPriceX96 = 2 ** 96; // Price = 1:1
        currentTick = 0;

        // Initialize LP token (ERC20)
        lpToken = new LPToken("DEX LP Token", "DEXLP");
        lpToken.setDexPoolAddress(address(this));
    }

    // =========================================================================
    // EXTERNAL FUNCTIONS - Liquidity Management
    // =========================================================================

    /// @notice Adds liquidity to the pool within the specified tick range.
    /// @param lowerTick The lower tick boundary of the liquidity position.
    /// @param upperTick The upper tick boundary of the liquidity position.
    /// @param liquidityDelta The amount of liquidity to add.
    function addLiquidity(
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidityDelta
    ) external nonReentrant {
        require(lowerTick < upperTick && liquidityDelta > 0, "Invalid params");

        if (lowerTick <= currentTick && currentTick < upperTick) {
            liquidity = uint128(uint256(liquidity) + uint256(liquidityDelta)); // Safe addition
        }

        uint160 sqrtA = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPrice = sqrtPriceX96;

        console.log("Liquidity before add:", liquidity);
        console.log("Amount0 and Amount1 before calculation:");

        (uint256 amount0, uint256 amount1) = _calculateAmounts(
            sqrtPrice,
            sqrtA,
            sqrtB,
            liquidityDelta
        );

        console.log("Amount0 calculated:", amount0);
        console.log("Amount1 calculated:", amount1);
        console.log(
            "Sender token0 balance before addLiquidity:",
            token0.balanceOf(msg.sender)
        );
        console.log(
            "Contract token0 balance before addLiquidity:",
            token0.balanceOf(address(this))
        );

        require(
            token0.transferFrom(msg.sender, address(this), amount0),
            "TRANSFER_FROM_FAILED"
        );
        require(
            token1.transferFrom(msg.sender, address(this), amount1),
            "TRANSFER_FROM_FAILED"
        );

        reserve0 = reserve0.add(amount0);
        reserve1 = reserve1.add(amount1);

        positions[msg.sender][lowerTick][upperTick].liquidity = uint128(
            uint256(positions[msg.sender][lowerTick][upperTick].liquidity).add(
                uint256(liquidityDelta)
            )
        );
        totalReserves = totalReserves.add(liquidityDelta);

        uint256 liquidityMinted;

        if (lpToken.totalSupply() == 0) {
            liquidityMinted = Math.sqrt(amount0 * amount1);
        } else {
            liquidityMinted = Math.min(
                (amount0 * lpToken.totalSupply()) / reserve0,
                (amount1 * lpToken.totalSupply()) / reserve1
            );
        }

        require(liquidityMinted > 0, "DEXPool: Insufficient liquidity minted");

        lpToken.mint(msg.sender, liquidityMinted);

        console.log("LP Tokens Minted:", liquidityMinted);

        emit LiquidityAdded(msg.sender, amount0, amount1, liquidityMinted);
    }

    /// @notice Removes liquidity from the pool within the specified tick range.
    /// @param lowerTick The lower tick boundary of the liquidity position.
    /// @param upperTick The upper tick boundary of the liquidity position.
    /// @param liquidityDelta The amount of liquidity to remove.
    function removeLiquidity(
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidityDelta
    ) external nonReentrant {
        require(lowerTick < upperTick && liquidityDelta > 0, "Invalid params");

        Position storage position = positions[msg.sender][lowerTick][upperTick];
        require(
            position.liquidity >= liquidityDelta,
            "Insufficient position liquidity"
        );

        position.liquidity -= liquidityDelta;

        if (lowerTick <= currentTick && currentTick < upperTick) {
            require(liquidity >= liquidityDelta, "Not enough pool liquidity");
            liquidity -= liquidityDelta;
            require(
                liquidity >= MIN_LIQUIDITY,
                "Total reserves cannot be zero"
            );
        }

        uint160 sqrtA = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPrice = sqrtPriceX96;

        (uint256 amount0, uint256 amount1) = _calculateAmounts(
            sqrtPrice,
            sqrtA,
            sqrtB,
            liquidityDelta
        );

        require(
            reserve0 >= amount0 && reserve1 >= amount1,
            "Insufficient reserves"
        );

        console.log("reserve0 before removal:", reserve0);
        console.log("reserve1 before removal:", reserve1);

        reserve0 -= amount0;
        reserve1 -= amount1;

        uint256 lpTokensToBurn = _burnLpTokens(amount0, amount1);

        lpToken.burnFrom(msg.sender, lpTokensToBurn);

        emit LiquidityRemoved(msg.sender, amount0, amount1, lpTokensToBurn);
    }

    // =========================================================================
    // EXTERNAL FUNCTIONS - Swaps
    // =========================================================================

    /// @notice Executes a simplified swap between two tokens.
    /// @param fromToken The address of the token being swapped from.
    /// @param amountIn The amount of the input token to swap.
    /// @param lowerTick The lower tick boundary of the price range for the swap.
    /// @param upperTick The upper tick boundary of the price range for the swap.
    /// @return amountOut The amount of the output token received.
    function simpleSwapV3(
        address fromToken,
        uint256 amountIn,
        int24 lowerTick,
        int24 upperTick
    ) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid Amount");
        require(
            fromToken == address(token0) || fromToken == address(token1),
            "Invalid Token"
        );
        require(lowerTick < upperTick, "Invalid tick range");

        bool zeroForOne = fromToken == address(token0);
        IERC20 inputToken = zeroForOne ? token0 : token1;
        IERC20 outputToken = zeroForOne ? token1 : token0;

        uint160 sqrtPriceStart = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceEnd = TickMath.getSqrtRatioAtTick(upperTick);

        uint256 maxAmountOut = zeroForOne
            ? LiquidityAmounts.getAmount1ForLiquidity(
                sqrtPriceStart,
                sqrtPriceEnd,
                liquidity
            )
            : LiquidityAmounts.getAmount0ForLiquidity(
                sqrtPriceStart,
                sqrtPriceEnd,
                liquidity
            );
        require(amountOut > 0, "Insufficient output");
        require(amountOut <= maxAmountOut, "Exceeds max output in range");

        uint256 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        // Calculate fee-adjusted input amount to minimize precision loss
        uint256 amountInWithFee = amountIn - (amountIn / 1000); //  amountIn * 997 / 1000
        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn + amountInWithFee); // SafeMath addition

        /// @notice ---------------- Oracle Price Validation ----------------- //
        /// @notice Assume: feed index 0 = token0, feed index 1 = token1
        (, int8 decimalsIn) = ftsoOracle.fetchPrice(zeroForOne ? 0 : 1);
        (uint256 priceOut, int8 decimalsOut) = ftsoOracle.fetchPrice(
            zeroForOne ? 1 : 0
        );

        require(decimalsIn >= 0 && decimalsOut >= 0, "Invalid decimals");

        /// @notice Normalize to 18 decimals
        uint256 normalizedPriceOut = priceOut *
            (10 ** (uint256(uint8(18)) - uint256(uint8(decimalsOut))));
        uint256 valueInUSD = (amountOut * normalizedPriceOut);
        uint256 valueOutUSD = (amountIn * normalizedPriceOut);

        require(valueOutUSD <= valueInUSD, "Oracle price validation failed");
        // ---------------------------------------------------------- //

        require(
            inputToken.transferFrom(msg.sender, address(this), amountIn),
            "TRANSFER_FROM_FAILED"
        );
        require(outputToken.transfer(msg.sender, amountOut), "TRANSFER_FAILED");

        // Update price
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(upperTick); // simplified price update
        currentTick = upperTick; // simplified tick update

        if (zeroForOne) {
            reserve0 = reserve0.add(amountIn); // SafeMath addition
            reserve1 = reserve1.sub(amountOut); // SafeMath subtraction
        } else {
            reserve1 = reserve1.add(amountIn); // SafeMath addition
            reserve0 = reserve0.sub(amountOut); // SafeMath subtraction
        }

        emit Swap(msg.sender, amountIn, amountOut, zeroForOne);
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    /// @notice Calculates the amounts of tokens 0 and 1 for a given liquidity amount and tick range.
    /// @param sqrtCurrentPrice The current square root price.
    /// @param sqrtA The square root price at the lower tick.
    /// @param sqrtB The square root price at the upper tick.
    /// @param _liquidity The amount of liquidity.
    /// @return amount0 The amount of token 0.
    /// @return amount1 The amount of token 1.
    function _calculateAmounts(
        uint160 sqrtCurrentPrice,
        uint160 sqrtA,
        uint160 sqrtB,
        uint128 _liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        // Ensure that liquidity is greater than 0 to prevent underflows
        require(_liquidity > 0, "Liquidity must be greater than zero");

        uint256 liquidity256 = uint256(_liquidity);
        uint256 sqrtPrice256 = uint256(sqrtCurrentPrice);
        uint256 sqrtA256 = uint256(sqrtA);
        uint256 sqrtB256 = uint256(sqrtB);
        uint256 Q96 = 2 ** 96;

        if (sqrtCurrentPrice <= sqrtA) {
            amount0 = (liquidity256 * (sqrtB256 - sqrtA256)) / Q96;
            amount1 = 0;
        } else if (sqrtCurrentPrice < sqrtB) {
            amount0 = (liquidity256 * (sqrtB256 - sqrtPrice256)) / Q96;
            amount1 = (liquidity256 * (sqrtPrice256 - sqrtA256)) / Q96;
        } else {
            amount0 = 0;
            amount1 = (liquidity256 * (sqrtB256 - sqrtA256)) / Q96;
        }
        return (amount0, amount1);
    }

    /// @notice Gets the reserves of token0 and token1 in the pool.
    /// @return _reserve0 The amount of token 0 in the pool.
    /// @return _reserve1 The amount of token 1 in the pool.
    function getReserves()
        public
        view
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        _reserve0 = token0.balanceOf(address(this));
        _reserve1 = token1.balanceOf(address(this));
    }

    /// @notice Gets the liquidity for a user within a specific tick range.
    /// @param user The address of the user.
    /// @param tickLower The lower tick boundary.
    /// @param tickUpper The upper tick boundary.
    /// @return The liquidity amount.
    function getLiquidityForUser(
        address user,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint128) {
        return positions[user][tickLower][tickUpper].liquidity;
    }

    /// @notice Gets the position details for a user within a specific tick range.
    /// @param user The address of the user.
    /// @param lowerTick The lower tick boundary.
    /// @param upperTick The upper tick boundary.
    /// @return The position details (liquidity, fee growth, and owed tokens).
    function getUserPosition(
        address user,
        int24 lowerTick,
        int24 upperTick
    ) external view returns (uint128, uint256, uint256, uint256, uint256) {
        Position memory pos = positions[user][lowerTick][upperTick];
        return (
            pos.liquidity,
            pos.feeGrowthInside0Last,
            pos.feeGrowthInside1Last,
            pos.tokensOwed0,
            pos.tokensOwed1
        );
    }

    /// @notice Calculates the liquidity amount for given token amounts and price range.
    /// @param sqrtPriceA The square root price at the lower tick.
    /// @param sqrtPriceB The square root price at the upper tick.
    /// @param amount0 The amount of token 0.
    /// @param amount1 The amount of token 1.
    /// @return _liquidity The calculated liquidity amount.
    function calculateLiquidity(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint256 amount0,
        uint256 amount1
    ) external pure returns (uint128 _liquidity) {
        if (sqrtPriceA > sqrtPriceB) {
            (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        }

        uint128 liquidity0 = uint128(
            ((amount0 * uint256(sqrtPriceA) * uint256(sqrtPriceB)) /
                (uint256(sqrtPriceB) - uint256(sqrtPriceA))) >> 96
        );

        uint128 liquidity1 = uint128(
            (amount1 << 96) / (sqrtPriceB - sqrtPriceA)
        );

        _liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    }

    // =========================================================================
    // INTERNAL FUNCTIONS - LP Token Management
    // =========================================================================

    /// @notice Mints LP tokens based on the provided token amounts.
    /// @param amount0 The amount of token 0.
    /// @param amount1 The amount of token 1.
    /// @return The amount of LP tokens minted.
    function _mintLpTokens(
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256) {
        uint256 totalSupply = lpToken.totalSupply();
        uint256 lpTokensToMint;

        if (totalSupply == 0) {
            // First liquidity provider, mint the LP tokens based on liquidity
            lpTokensToMint = sqrt(amount0 * amount1);
        } else {
            // Mint LP tokens proportional to the amount of liquidity provided
            lpTokensToMint =
                ((amount0 + amount1) * totalSupply) /
                (reserve0 + reserve1);
        }

        lpToken.mint(msg.sender, lpTokensToMint);
        return lpTokensToMint;
    }

    /// @notice Burns LP tokens based on the withdrawn token amounts.
    /// @param amount0 The amount of token 0.
    /// @param amount1 The amount of token 1.
    /// @return The amount of LP tokens burned.
    function _burnLpTokens(
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256) {
        uint256 totalSupply = lpToken.totalSupply();
        uint256 _totalReserves = reserve0 + reserve1;
        uint256 lpTokensToBurn;

        require(_totalReserves > 0, "Total reserves cannot be zero"); // Add this check

        lpTokensToBurn = ((amount0 + amount1) * totalSupply) / totalReserves;

        lpToken.burnFrom(msg.sender, lpTokensToBurn);
        return lpTokensToBurn;
    }

    // =========================================================================
    // INTERNAL FUNCTIONS - Math
    // =========================================================================

    /// @notice Calculates the square root of a number.
    /// @param x The input number.
    /// @return The square root of x.
    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
