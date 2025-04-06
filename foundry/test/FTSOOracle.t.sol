//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Test} from "forge-std/Test.sol";
import {FTSOOracle} from "../src/FTSOOracle.sol";

contract FTSOOracleTest is Test {
    FTSOOracle public ftsoOracle;

    function setUp() public {

        address ftsoV2Address = 0xDdCeCE51850C5D15B7dc2a8701c092FC45155E90;

        ftsoOracle = FTSOOracle(ftsoV2Address);
    }

    function testFetchPrice() public view {
        uint8 feedArrayIndex = 0;
        (uint256 value, int8 decimals) = ftsoOracle.fetchPrice(feedArrayIndex);

        assert(value > 0);
        assert(decimals >= 0);     
    }
}