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

        ERC20Mock(weth).mint(USER, AMOUNT_TO_MINT);
    }

    //Constructor tests
    function testRevertsIfTokenLegthDoesNotMatchPriceFeedLength() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](2);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(address(dsc), tokenAddresses, priceFeedAddresses);
    }

    function testRevertsIfDscAddressIsZero() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](1);
        vm.expectRevert(DSCEngine.DSCEngine__DscAddressCantBeZero.selector);
        new DSCEngine(address(0), tokenAddresses, priceFeedAddresses);
    }

    function testConstructorSetsAddressesCorrectly() public {
        address[] memory collateraltokens = dsce.getCollateralTokens();
        assertEq(address(dsc), address(dsce.i_dsc()));
        assertEq(weth, collateraltokens[0]);
        assertEq(wbtc, collateraltokens[1]);
        assertEq(ethUsdPriceFeed, dsce.s_priceFeeds(weth));
        assertEq(btcUsdPriceFeed, dsce.s_priceFeeds(wbtc));
    }

    //PriceFeed tests
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18; //15e18 * 2000/ETH
        uint256 actualUsd = dsce.getUSDValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 3000e18;
        uint256 expectedWeth = 1.5e18; //3000/2000
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //depositCollateralTest
    function testDepositFunctionWorksOrRevertsIfDepositZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(address(weth), 0);
    }

    function testRevertsIfCollateralTokenNotApproved() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccounInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositAmount, AMOUNT_COLLATERAL);
    }
}