// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DEX Liquidity Pool Contract
/// @author 
/// @notice This contract allows users to provide and remove liquidity for a token pair
/// @dev Uses ReentrancyGuard to prevent reentrancy vulnerabilities during token transfers
contract DEXPool is ReentrancyGuard {
    /// @notice First token of the pool
    IERC20 public token0;

    /// @notice Second token of the pool
    IERC20 public token1;

    /// @notice Reserve amount of token0 held by the pool
    uint256 public reserve0;

    /// @notice Reserve amount of token1 held by the pool
    uint256 public reserve1;

    /// @notice Emitted when liquidity is added to the pool
    /// @param amount0 Amount of token0 added
    /// @param amount1 Amount of token1 added
    event LiquidityAdded(uint256 indexed amount0, uint256 indexed amount1);

    /// @notice Emitted when liquidity is removed from the pool
    /// @param amount0 Amount of token0 removed
    /// @param amount1 Amount of token1 removed
    event LiquidityRemoved(uint256 indexed amount0, uint256 indexed amount1);

    /// @notice Initializes the pool with two token addresses
    /// @param _token0 Address of the first token
    /// @param _token1 Address of the second token
    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    /// @notice Adds liquidity to the pool by transferring tokens from the user
    /// @dev Updates internal reserves after token transfers
    /// @param amount0 Amount of token0 to deposit
    /// @param amount1 Amount of token1 to deposit
    function addLiquidity(
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant {
        require(amount0 > 0 && amount1 > 0, "Amounts must be > 0");

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        reserve0 += amount0;
        reserve1 += amount1;

        emit LiquidityAdded(amount0, amount1);
    }

    /// @notice Removes liquidity from the pool and sends tokens back to the user
    /// @dev Checks if the reserves are sufficient before allowing withdrawal
    /// @param amount0 Amount of token0 to withdraw
    /// @param amount1 Amount of token1 to withdraw
    function removeLiquidity(
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant {
        require(amount0 > 0 && amount1 > 0, "Amounts must be > 0");
        require(
            reserve0 >= amount0 && reserve1 >= amount1,
            "Insufficient reserves"
        );

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        reserve0 -= amount0;
        reserve1 -= amount1;

        emit LiquidityRemoved(amount0, amount1);
    }
}
