// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LPToken is ERC20, ERC20Burnable {
    address public dexPoolAddress;
    uint256 public totalValue;

    modifier onlyDexPool() {
        require(msg.sender == dexPoolAddress, "Not authorized");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function setDexPoolAddress(address _dexPoolAddress) external {
        require(dexPoolAddress == address(0), "DexPool address already set");
        require(_dexPoolAddress != address(0), "Invalid DexPool address");
        dexPoolAddress = _dexPoolAddress;
    }


    function mint(address to, uint256 amount) external onlyDexPool {
        require(amount > 0, "Cannot mint zero amount");
        _mint(to, amount);
    }

    function burnFromDexPool(
        address from,
        uint256 amount
    ) external onlyDexPool {
        require(amount > 0, "Cannot burn zero amount");
        _burn(from, amount);
    }

    function fetchPrice(uint256 amount) public view returns (uint256) {
        return (amount * totalValue) / totalSupply();
    }

    function _burn(address account, uint256 amount) internal virtual override {
        totalValue -= amount;
        super._burn(account, amount);
        
    }

    // Override the mint function to correctly update totalValue
    function _mint(address to, uint256 amount) internal virtual override {
        require(amount > 0, "LPToken: Cannot mint zero amount");
        totalValue += amount;
        super._mint(to, amount);
        
    }
}
