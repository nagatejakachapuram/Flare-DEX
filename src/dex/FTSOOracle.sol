// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {TestFtsoV2Interface} from "../../lib/flare-periphery-contracts/flare/TestFtsoV2Interface.sol";

import {ContractRegistry} from "../../lib/flare-periphery-contracts/coston2/ContractRegistry.sol";

interface IFTSOOracle {
    function fetchPrice(
        uint8 feedArrayIndex
    ) external view returns (uint256, int8);
}

contract FTSOOracle {
    bytes21[] private feedIds;
    TestFtsoV2Interface internal ftsoV2;

    // Constructor to initialize the contract with feed IDs
    constructor(bytes21[] memory _feedIds) {
        feedIds = _feedIds;
        ftsoV2 = TestFtsoV2Interface(address(ContractRegistry.getTestFtsoV2()));
    }

    // Function to fetch the price from the FTSO
    function fetchPrice(
        uint8 _feedArrayIndex
    ) public view returns (uint256, int8) {
        bytes21 feedId = feedIds[_feedArrayIndex];
        (uint256 _value, int8 _decimals, ) = ftsoV2.getFeedById(feedId);
        return (_value, _decimals);
    }
}
