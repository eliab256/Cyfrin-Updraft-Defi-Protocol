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
    uint256 constant AMOUNT_DSC_TO_MINT = 5 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (weth, wbtc, ethUsdPriceFeed, btcUsdPriceFeed, ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, AMOUNT_TO_MINT);
        ERC20Mock(wbtc).mint(USER, AMOUNT_TO_MINT);
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
        modifier depositedCollateral(address _token) {
        vm.startPrank(USER);
        
        ERC20Mock(_token).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(_token), AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

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

    function testCanDepositCollateralAndGetAccounInfo() public depositedCollateral(weth) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositAmount, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralFunctionTransferCollateralAndEmitsEvent() public {
        uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(USER);
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.prank(USER);
        vm.expectEmit(true, true, false, false);
        emit DSCEngine.CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 dsceBalance = ERC20Mock(weth).balanceOf(address(dsce));
        uint256 userBalanceAfter = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalanceBefore - userBalanceAfter, AMOUNT_COLLATERAL);
        assertEq(dsceBalance, AMOUNT_COLLATERAL);
    }

    //test mint functions

    function testRevertsIfMintAmountIsZero() public depositedCollateral(weth) {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
    }

    // function testRevertsIfHealthFactorIsTooLow() public depositedCollateral(weth) {
    //     vm.prank(USER);
    //     uint256 amountToMint = 8000e18; //collateral is worth 20000 usd, so minting 8000 should make health factor < 1
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     dsce.mintDsc(amountToMint);
    // }

    function testMintFunctionWorksAndUpdateStateCorrectly() public depositedCollateral(weth) {
        vm.prank(USER);
        dsce.mintDsc(AMOUNT_TO_MINT);
        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, AMOUNT_TO_MINT);
    }

    function testIfDepositAndMintWorks() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, false, false);
        emit DSCEngine.CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth,AMOUNT_COLLATERAL,  AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
    }

    //test burn functions
    modifier DepositAndMintDsc(address _token) {
        vm.startPrank(USER);
        ERC20Mock(_token).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(_token, AMOUNT_COLLATERAL);
        dsce.mintDsc(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testRevertsIfBurnAmountIsZero() public DepositAndMintDsc(wbtc) {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
    }

    function testBurnFunctionWorksAndUpdateStateCorrectly() public DepositAndMintDsc(wbtc) {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_DSC_TO_MINT);
        dsce.burnDsc(AMOUNT_DSC_TO_MINT);
        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
    }

    //test redeem functions
    function testRevertsIfRedeemAmountIsZero() public DepositAndMintDsc(weth) {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
    }

    function testRedeemeUpdateStateAndEmitEvent() public DepositAndMintDsc(weth) {
        uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(USER);
        uint256 amountToRedeem = AMOUNT_COLLATERAL / 2;
        vm.prank(USER);
        vm.expectEmit(true, true, false, false);
        emit DSCEngine.CollateralRedeemed(USER, USER, weth, amountToRedeem);
        dsce.redeemCollateral(weth, amountToRedeem);
        (uint256 totalDeposited, ) = dsce.getAccountInformation(USER);
        uint256 userBalanceAfter = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalanceAfter - userBalanceBefore, amountToRedeem);
        assertEq(totalDeposited, AMOUNT_COLLATERAL - amountToRedeem);
    }

    function testRedeemAndBurnFunctionWorksAndEmitEvent() public DepositAndMintDsc(weth) {
        uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(USER);
        uint256 amountToRedeem = AMOUNT_COLLATERAL / 2;
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_DSC_TO_MINT);
        // vm.expectEmit(true, true, false, false);
        // emit DSCEngine.CollateralRedeemed(USER, USER, weth, amountToRedeem);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        // (uint256 totalDeposited, uint256 totalDscMinted) = dsce.getAccountInformation(USER);
        // uint256 userBalanceAfter = ERC20Mock(weth).balanceOf(USER);
        // assertEq(userBalanceAfter - userBalanceBefore, amountToRedeem);
        // assertEq(totalDeposited, AMOUNT_COLLATERAL - amountToRedeem);
        // assertEq(totalDscMinted, 0);
    }




}