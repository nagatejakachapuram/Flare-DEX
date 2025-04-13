// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../src/dex/DEXFactory.sol";
import {Test} from "forge-std/Test.sol";
import "../src/mocks/mockERC20.sol";

contract TestDEXFactory is Test {
    DEXFactory dexFactory;
    MockERC20 tokenA;
    MockERC20 tokenB;
    address public oracleAddress = address(0xBF55AFB5d543db03f55852B02973B24345EAd1e1);
    

    function setUp() public{
        tokenA = new MockERC20("tokenA", "TA", 18);
        tokenB = new MockERC20("tokenB","TB",18);

        dexFactory = new DEXFactory();
    }

    function testPoolCreation() public {
        address pair = dexFactory.createPool(address(tokenA),address(tokenB),oracleAddress);
        assertTrue(pair != address(0),"Pool not created");
    }

    function testPoolCreatedWithSameToken() public {
        vm.expectRevert("Identical tokens");
        dexFactory.createPool(address(tokenA),address(tokenA),oracleAddress);
    }

}