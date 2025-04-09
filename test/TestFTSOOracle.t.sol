//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test} from "forge-std/Test.sol";
import {FTSOOracle} from "../src/dex/FTSOOracle.sol";
import {console} from "forge-std/console.sol";

contract FTSOOracleTest is Test {
    FTSOOracle public ftsoOracle;

    function setUp() public {
        address ftsoV2Address = 0xBF55AFB5d543db03f55852B02973B24345EAd1e1;

        ftsoOracle = FTSOOracle(ftsoV2Address);
    }

    function testFetchPrice() public view {
        uint8 feedArrayIndex = 2;
        (uint256 value, int8 decimals) = ftsoOracle.fetchPrice(feedArrayIndex);
        console.log("Value: ", value);
        console.log("Decimals: ", decimals);
        assert(value > 0);
        assert(decimals >= 0);
    }
}
