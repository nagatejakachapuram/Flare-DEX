// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TestFtsoV2Interface} from "@flare-smart-contracts/TestFtsoV2Interface.sol";
import {ContractRegistry} from "@flare-smart-contracts/ContractRegistry.sol";

///Current Deployment on Coston2 : 0xBF55AFB5d543db03f55852B02973B24345EAd1e1
contract FTSOOracle {
    bytes21[] private feedIds;
    TestFtsoV2Interface internal ftsoV2;

    

    // Constructor to initialize the contract with feed IDs
    constructor(bytes21[] memory _feedIds) {
        feedIds = _feedIds;
        ftsoV2 = ContractRegistry.getTestFtsoV2();
    }

    // Function to fetch the price from the FTSO
    function fetchPrice(uint8 _feedArrayIndex) public view returns (uint256, int8) {
        bytes21 feedId = feedIds[_feedArrayIndex];
        (uint256 _value, int8 _decimals, ) = ftsoV2.getFeedById(feedId);
        return (_value, _decimals);
    }
}
