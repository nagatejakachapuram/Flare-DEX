// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./DEXPool.sol";

/// @title DEX Factory Contract
/// @author
/// @notice This contract is responsible for deploying and tracking individual token pair pools
/// @dev Ensures unique token pair combinations using sorted addresses for consistency
contract DEXFactory {
    /// @notice Address of the factory owner
    address public owner;

    /// @notice Mapping to retrieve pool address by token pair
    /// @dev Always stores pool with token0 < token1 for uniqueness
    mapping(address => mapping(address => address)) public getPool;

    /// @notice List of all deployed pools
    address[] public allPools;

    /// @notice Emitted when a new liquidity pool is deployed
    /// @param token0 First token of the pair (sorted)
    /// @param token1 Second token of the pair (sorted)
    /// @param pool Address of the deployed DEXPool
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address indexed pool
    );

    /////////////////////////////////////
    ////// Constructor /////
    /////////////////////////////////////

    /// @notice Initializes the factory and sets the deployer as the owner
    constructor() {
        owner = msg.sender;
    }

    /////////////////////////////////////
    ////// External Functions /////
    /////////////////////////////////////

    /// @notice Deploys a new DEXPool for a given token pair if one doesn't exist
    /// @dev Enforces token order to prevent duplicate pools for the same pair
    /// @param _tokenA Address of the first token
    /// @param _tokenB Address of the second token
    /// @return pool The address of the newly created DEXPool
    function createPool(
        address _tokenA,
        address _tokenB
    ) external returns (address pool) {
        require(_tokenA != _tokenB, "Identical tokens");

        // Ensure consistent ordering of token addresses
        (address token0, address token1) = _tokenA < _tokenB
            ? (_tokenA, _tokenB)
            : (_tokenB, _tokenA);

        require(getPool[token0][token1] == address(0), "Pool exists");

        // Deploy and store new DEX pool
        DEXPool newPool = new DEXPool(token0, token1);
        pool = address(newPool);

        getPool[token0][token1] = pool;
        allPools.push(pool);

        emit PoolCreated(token0, token1, pool);
    }
}
