// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {TestFtsoV2Interface} from "../../lib/flare-periphery-contracts/flare/TestFtsoV2Interface.sol";
import {ContractRegistry} from "../../lib/flare-periphery-contracts/coston2/ContractRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

interface IFTSOOracle {
    function fetchPrice(
        uint256 feedIndex
    ) external view returns (uint256, int8);
}
contract MockFTSOOracle is IFTSOOracle {
    uint256 public price;
    int8 public decimals;

    constructor(uint256 _price, int8 _decimals) {
        price = _price;
        decimals = _decimals;
    }

    function fetchPrice(uint256) external view returns (uint256, int8) {
        return (price, decimals);
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setDecimals(int8 _decimals) external {
        decimals = _decimals;
    }
}
