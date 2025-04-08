// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "v3-core/contracts/libraries/FullMath.sol";

interface IFTSOOracle {
     function fetchPrice(uint8 _feedArrayIndex) public external returns (uint256, int8)
}

/// @title DEXPool - A Simplified  Decentralized Exchange Pool
/// @author
/// @notice Supports adding/removing liquidity and performing swaps within specific tick ranges

contract DEXPool is ReentrancyGuard {
    using LiquidityAmounts for uint128;
     
    uint8 constant precision = 18;

    IFTSOOracle public oracle;

    /// @notice Token0 of the trading pair
    IERC20 public token0;

    /// @notice Token1 of the trading pair
    IERC20 public token1;

    uint8 public token0FeedId;

    uint8 public token1FeedId;

    /// @notice Reserve of token0 in the pool
    uint256 public reserve0;

    /// @notice Reserve of token1 in the pool
    uint256 public reserve1;

    /// @notice Current sqrt(price) as a Q64.96 fixed point number
    uint160 public sqrtPriceX96;

    /// @notice Current active tick
    int24 public currentTick;

    /// @notice Total liquidity at the current active tick
    uint128 public liquidity;

    /// @notice Structure to hold tick-level liquidity information
    /// @param liquidityNet Net liquidity change when crossing this tick
    /// @param liquidityGross Total liquidity deposited at this tick
    struct Tick {
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    /// @notice Mapping of tick index to Tick struct
    mapping(int24 => Tick) public ticks;

    /// @notice Event emitted when liquidity is added to the pool
    event LiquidityAdded(uint256 amount0, uint256 amount1);

    /// @notice Event emitted when liquidity is removed from the pool
    event LiquidityRemoved(uint256 amount0, uint256 amount1);

    /// @notice Event emitted when a swap is executed
    event Swap(
        address indexed sender,
        uint256 indexed amountIn,
        uint256 indexed amountOut,
        bool zeroForOne
    );

    /////////////////////////////////////
    ////// Constructor /////////////////
    /////////////////////////////////////

    /// @notice Initializes the DEXPool contract with two ERC20 tokens
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    constructor(address _token0, uint8 _token0FeedId, address _token1, uint8 _token1FeedId, address _priceOracle) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        // Set initial sqrt price to 1.0 in Q64.96 format (i.e., 2^96)
        sqrtPriceX96 = 2 ** 96;

        // Initialize current tick to 0, corresponding to a price ratio of 1:1
        currentTick = 0;

        oracle = IFTSOOracle(_priceOracle);

        token0FeedId = _token0FeedId;
        token1FeedId = _token1FeedId;
    }

    /////////////////////////////////////
    ////// External functions //////////
    /////////////////////////////////////

    /// @notice Adds liquidity to a specific tick range
    /// @param lowerTick Lower bound of the tick range
    /// @param upperTick Upper bound of the tick range
    /// @param liquidityDelta Amount of liquidity to be added
    function addLiquidity(
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidityDelta
    ) external nonReentrant {
        require(lowerTick < upperTick && liquidityDelta > 0, "Invalid params");

        ticks[lowerTick].liquidityGross += liquidityDelta;
        ticks[upperTick].liquidityGross += liquidityDelta;
        ticks[lowerTick].liquidityNet += int128(liquidityDelta);
        ticks[upperTick].liquidityNet -= int128(liquidityDelta);

        if (lowerTick <= currentTick && currentTick < upperTick) {
            liquidity += liquidityDelta;
        }

        uint160 sqrtRatioA = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtRatioB = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPrice = sqrtPriceX96;

        (uint256 amount0, uint256 amount1) = _calculateAmounts(
            sqrtPrice,
            sqrtRatioA,
            sqrtRatioB,
            liquidityDelta
        );

        reserve0 += amount0;
        reserve1 += amount1;

        require(
            token0.transferFrom(msg.sender, address(this), amount0),
            "TRANSFER_FROM_FAILED"
        );
        require(
            token1.transferFrom(msg.sender, address(this), amount1),
            "TRANSFER_FROM_FAILED"
        );

        emit LiquidityAdded(amount0, amount1);
    }

    /// @notice Removes liquidity from a specific tick range
    /// @param lowerTick Lower bound of the tick range
    /// @param upperTick Upper bound of the tick range
    /// @param liquidityDelta Amount of liquidity to be removed
    function removeLiquidity(
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidityDelta
    ) external nonReentrant {
        require(lowerTick < upperTick && liquidityDelta > 0, "Invalid params");

        ticks[lowerTick].liquidityGross -= liquidityDelta;
        ticks[upperTick].liquidityGross -= liquidityDelta;

        if (lowerTick <= currentTick && currentTick < upperTick) {
            liquidity -= liquidityDelta;
        }

        uint160 sqrtRatioA = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtRatioB = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPrice = sqrtPriceX96;

        (uint256 amount0, uint256 amount1) = _calculateAmounts(
            sqrtPrice,
            sqrtRatioA,
            sqrtRatioB,
            liquidityDelta
        );

        require(
            reserve0 >= amount0 && reserve1 >= amount1,
            "Insufficient reserves"
        );

        reserve0 -= amount0;
        reserve1 -= amount1;

        require(token0.transfer(msg.sender, amount0), "TRANSFER_FAILED");

        require(token1.transfer(msg.sender, amount1), "TRANSFER_FAILED");

        emit LiquidityRemoved(amount0, amount1);
    }

    /// @notice Executes a basic swap operation within a tick range
    /// @dev No tick crossing supported in this simplified version
    /// @param fromToken Address of the token sent into the pool
    /// @param amountIn Amount of input token to swap
    /// @param lowerTick Lower tick boundary of the price range
    /// @param upperTick Upper tick boundary of the price range
    /// @return amountOut The resulting amount of output token
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

        uint256 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        uint256 amountInWithFee = amountIn * 997;
        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn * 1000 + amountInWithFee);

        require(amountOut > 0, "Insufficient output");
        require(amountOut <= maxAmountOut, "Exceeds max output in range");

        if (zeroForOne) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        require(
            inputToken.transferFrom(msg.sender, address(this), amountIn),
            "TRANSFER_FROM_FAILED"
        );
        require(outputToken.transfer(msg.sender, amountOut), "TRANSFER_FAILED");

        emit Swap(msg.sender, amountIn, amountOut, zeroForOne);
    }

    function redeemAsset(address _tokenAddress, uint256 _amount) public {
        if(_tokenAddress = address(token0)) {
            //TODO: @Nagateja
            //check for available balance of token0 to be redeemed
            //uint256 balance = 
            //
            int8 token0Decimals = int8(token0.decimals());
            
            uint0 token0BalanceCorrected = /*balance*/ * 10 ** (precision - token0Decimals);
            (uint256 price, int8 decimals) = oracle.fetchPrice(token0FeedId);
            uint256 priceCorrected = price * 10 ** (precision - decimals);

            uint256 amount = (token0BalanceCorrected * priceCorrected) / 10 ** precision;

            (bool success,) = payable(msg.sender).call{value: amount}();
            require(success, "Transfer failed");
        }
        else if (_tokenAddress = address(token1)){
            //TODO: @Nagateja
            //check for available balance of token1 to be redeemed
            //uint256 balance = 
            //
            int8 token1Decimals = int8(token1.decimals());
            uint0 token1BalanceCorrected = /*balance*/ * 10 ** (precision - token1Decimals);
            (uint256 price, int8 decimals) = oracle.fetchPrice(token1FeedId);
            uint256 priceCorrected = price * 10 ** (precision - decimals);

            uint256 amount = (token1BalanceCorrected * priceCorrected) / 10 ** precision;

            (bool success,) = payable(msg.sender).call{value: amount}();
            require(success, "Transfer failed");
        }
        else {
            revert("Invalid Token Address");
        }
        
    }

    /////////////////////////////////////
    ////// Internal functions //////////
    /////////////////////////////////////

    /// @notice Calculates required token amounts based on sqrt price and liquidity
    /// @param sqrtCurrentPrice Current sqrt price (Q64.96) format
    /// @param sqrtA Lower bound sqrt price
    /// @param sqrtB Upper bound sqrt price
    /// @param liq Liquidity amount
    /// @return amount0 Required amount of token0
    /// @return amount1 Required amount of token1
    function _calculateAmounts(
        uint160 sqrtCurrentPrice,
        uint160 sqrtA,
        uint160 sqrtB,
        uint128 liq
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtCurrentPrice <= sqrtA) {
            amount0 = LiquidityAmounts.getAmount0ForLiquidity(
                sqrtA,
                sqrtB,
                liq
            );
        } else if (sqrtCurrentPrice < sqrtB) {
            amount0 = LiquidityAmounts.getAmount0ForLiquidity(
                sqrtCurrentPrice,
                sqrtB,
                liq
            );
            amount1 = LiquidityAmounts.getAmount1ForLiquidity(
                sqrtA,
                sqrtCurrentPrice,
                liq
            );
        } else {
            amount1 = LiquidityAmounts.getAmount1ForLiquidity(
                sqrtA,
                sqrtB,
                liq
            );
        }
    }

   
}
