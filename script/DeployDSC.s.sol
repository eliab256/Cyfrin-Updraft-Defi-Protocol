// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DSCEngine}from "../src/DSCEngine.sol"; 
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";


contract CounterScript is Script {
   
    function setUp() public {}

    function run() public returns(DecentralizedStableCoin, DSCEngine){
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine();
        vm.stopBroadcast();
    }
}
