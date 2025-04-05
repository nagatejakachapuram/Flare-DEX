// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./DEXPool.sol";

/// @title DEX Factory
/// @author 
/// @notice This contract allows the creation of token pools for a DEX
/// @dev Deploys DEXPool contracts for token pairs and keeps track of them
contract DEXFactory {
    /// @notice Owner of the factory
    address public owner;

    /// @notice Mapping from token pair to deployed pool address
    /// @dev token0 < token1 is enforced for consistency
    mapping(address => mapping(address => address)) public getPool;

    /// @notice Array of all created pool addresses
    address[] public allPools;

    /// @notice Emitted when a new pool is created
    /// @param token0 The first token of the pair
    /// @param token1 The second token of the pair
    /// @param pool The address of the newly created pool
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address indexed pool
    );

    /// @notice Initializes the factory and sets the owner
    constructor() {
        owner = msg.sender;
    }

    /// @notice Creates a new pool for the given token pair
    /// @dev Deploys a new DEXPool contract if it doesn't already exist
    /// @param _tokenA Address of the first token
    /// @param _tokenB Address of the second token
    /// @return pool Address of the newly created pool
    function createPool(
        address _tokenA,
        address _tokenB
    ) external returns (address pool) {
        require(_tokenA != _tokenB, "Identical tokens");

        // Sort tokens by address to enforce uniqueness
        (address token0, address token1) = _tokenA < _tokenB
            ? (_tokenA, _tokenB)
            : (_tokenB, _tokenA);

        require(getPool[token0][token1] == address(0), "Pool exists");

        // Deploy new pool
        DEXPool newPool = new DEXPool(token0, token1);
        pool = address(newPool);

        // Register pool
        getPool[token0][token1] = pool;
        allPools.push(pool);

        emit PoolCreated(token0, token1, pool);
    }
}
