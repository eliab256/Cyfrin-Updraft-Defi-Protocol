//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test{
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    uint256 public timesMintIsCalled;
    address [] public userWithCollateralDeposited;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc){
        dsce = _dscEngine;
        dsc = _dsc;

        address[ ] memory tokenAddresses = dsce.getCollateralTokens();
        weth = ERC20Mock(tokenAddresses[0]);
        wbtc = ERC20Mock(tokenAddresses[1]);

        ethUsdPriceFeed =  MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed =  MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
    }

    function mintDsc(uint256 amountDsc) public {
        (uint256 totaldscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(msg.sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) /2)- int256(totaldscMinted);
        if(maxDscToMint < 0){
            return;
        }
        amountDsc = bound(amountDsc, 0 , uint256(maxDscToMint));
         if( amountDsc == 0){
             return;
         }

        vm.startPrank(msg.sender);
        dsce.mintDsc(amountDsc);
        vm.stopPrank();
    }

    //redeem collateral
    function depositCollateral(/*address tokenCollateral*/ uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock tokenCollateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1 , MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        tokenCollateral.mint(msg.sender, amountCollateral);
        tokenCollateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(tokenCollateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock tokenCollateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(msg.sender, address(tokenCollateral));
        amountCollateral = bound(amountCollateral, 1 , maxCollateralToRedeem);
        if( amountCollateral == 0){
             return;
         }
        dsce.redeemCollateral(address(tokenCollateral), amountCollateral);
      
    }

    //This test brake our invariant
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }


    //helper fuunctions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
        if(collateralSeed % 2 == 0){
            return weth;
        } else{
            return wbtc;
        }
    }
}