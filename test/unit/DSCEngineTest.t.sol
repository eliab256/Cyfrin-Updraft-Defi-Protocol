// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Script.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;

    function setuUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
    }

    //PriceFeed tests

    function testGetUsdValue() public {

    }
}