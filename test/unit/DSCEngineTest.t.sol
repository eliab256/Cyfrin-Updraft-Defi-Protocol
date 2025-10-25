// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;

    address public USER = makeAddr("user");
    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant AMOUNT_TO_MINT = 1000 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (weth, wbtc, ethUsdPriceFeed, btcUsdPriceFeed, ) = config.activeNetworkConfig();
        console.log("Deployed dsce", address(dsce));

        ERC20Mock(weth).mint(USER, AMOUNT_TO_MINT);
    }

    //PriceFeed tests
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18; //15e18 * 2000/ETH
        uint256 actualUsd = dsce.getUSDValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    //depositCollateralTest
    function testDepositFunctionWorksOrRevertsIfDepositZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(address(weth), 0);

    }
}