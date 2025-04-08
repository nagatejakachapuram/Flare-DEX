// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20 Token
/// @notice Simple ERC20 mock token for testing
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    /// @notice Initializes the mock token with name, symbol, decimals
    /// @param name_ Name of the token
    /// @param symbol_ Symbol of the token
    /// @param decimals_ Number of decimals
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    /// @notice Override decimals to use custom
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Mints tokens to an address for testing
    /// @param to Address to receive the tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
