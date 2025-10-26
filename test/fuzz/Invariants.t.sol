//What are our invariants?
//1. The total supply of DSC should be less than the total value  of collateral in the sistem
//2. Getter view functions should never revert

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invartiants is StdInvariant, Test{
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;
    Handler handler;

    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    // uint256 deployerKey;

    uint256 constant STARTING_USER_BALANCE = 10 ether;
    address user = makeAddr("user");


    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        
        (weth, wbtc, ethUsdPriceFeed, btcUsdPriceFeed, ) = helperConfig.activeNetworkConfig();
        // if (block.chainid == 31_337) {
        //     vm.deal(user, STARTING_USER_BALANCE);
        // }
        //targetContract(address(dsce));
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view{
        //get the total value of collaterals
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUSDValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUSDValue(wbtc, totalWbtcDeposited);

        console.log("WETH value in USD: ", wethValue);
        console.log("WBTC value in USD: ", wbtcValue);
        console.log("Total DSC supply  : ", totalSupply);

        assert(wethValue + wbtcValue >= totalSupply);
    }

}