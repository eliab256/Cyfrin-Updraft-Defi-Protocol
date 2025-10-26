// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//import { OracleLib, AggregatorV3Interface } from "./libraries/OracleLib.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DecentralizedStableCoin } from "./DecentralizedStableCoin.sol";
//import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interface/AggregatorV3Interfsce.sol";
import {AggregatorV3Interface} from "lib/localDependencies/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";


/*
 * @title DSCEngine
 * @author Elia Bordoni
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is ReentrancyGuard {

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__DscAddressCantBeZero();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__CollateralDepositFailed(address collateralToken);
    error DSCEngine__CollateralRedeemFailed(address tokenCollateral);
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__DscMintFailed();
    error DSCEngine__DscBurnFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    DecentralizedStableCoin public immutable i_dsc;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50; //200% overcollateralized
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10;  //means 10%
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; 
    /// @dev Mapping of token address to price feed address
    mapping(address token => address priceFeed) public s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address tokenCollateral => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of DSC minted by user
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;
    

    event CollateralDeposited(address indexed depositer, address indexed tokenCollateral, uint256 indexed collateralAmount);
    event CollateralRedeemed(address indexed redeemeFrom, address indexed redeemeTo, address indexed tokenCollateral, uint256 collateralAmount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedCollateral(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(
        
        address[] memory _tokenCollateral,
        address[] memory _priceFeed,
        address _dscAddress
    ) {
        if (_tokenCollateral.length != _priceFeed.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        if (_dscAddress == address(0)) {
            revert DSCEngine__DscAddressCantBeZero();
        }
        for (uint256 i = 0; i < _tokenCollateral.length; i++) {
            s_priceFeeds[_tokenCollateral[i]] = _priceFeed[i];
            s_collateralTokens.push(_tokenCollateral[i]);
        }
        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

//////////////////////////////////
// External and Public Functions//
//////////////////////////////////
    function depositCollateralAndMintDsc(address _tokenCollateral, uint256 _collateralAmount, uint256 _amountDscToMint) external{
        depositCollateral(_tokenCollateral, _collateralAmount);
        mintDsc(_amountDscToMint);
    }

    function depositCollateral(address _tokenCollateral, uint256 _collateralAmount)
        public
        moreThanZero(_collateralAmount)
        isAllowedCollateral(_tokenCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenCollateral] += _collateralAmount;
        bool success = IERC20(_tokenCollateral).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!success) {
            revert DSCEngine__CollateralDepositFailed(_tokenCollateral);
        }

        emit CollateralDeposited(msg.sender, _tokenCollateral, _collateralAmount);
    }

    function redeemCollateralForDsc(address _tokenCollateral, uint256 _collateralAmount, uint256 _amountDscToBurn) external {
        burnDsc(_amountDscToBurn);
        redeemCollateral(_tokenCollateral, _collateralAmount);
        //redeeme collatera already checks healthFactor
    }

    function redeemCollateral(address _tokenCollateral, uint256 _collateralAmount) public nonReentrant moreThanZero(_collateralAmount){
        _redeemCollateral(_tokenCollateral, _collateralAmount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintDsc(uint256 _amountDscToMint) public moreThanZero(_amountDscToMint) nonReentrant{
        s_DscMinted[msg.sender] += _amountDscToMint;
       
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _amountDscToMint);
        if(!minted){
            revert DSCEngine__DscMintFailed();
        }
    }

    function burnDsc(uint256 _amountToBurn) public moreThanZero(_amountToBurn){
        _burnDsc(_amountToBurn, msg.sender,msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); //I don't think this would ever hit.
    }

    function liquidate(address _tokenCollateral,  address _user, uint256 _debtToCover) external moreThanZero(_debtToCover) nonReentrant{
        uint256 startingUserHealthFactor = _healthFactor(_user);
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(_tokenCollateral, _debtToCover);
        //We add 10% bonus to the liquidators to incentivize them
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        //calculate amount and send collateral to liquidator
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(_tokenCollateral, totalCollateralToRedeem, _user, msg.sender);

        //burn debt covered
        _burnDsc(_debtToCover, _user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(_user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

///////////////////////////////////
// Private and internal Functions//
///////////////////////////////////

    function _burnDsc(uint256 _amountToBurn, address _onBehalfOf, address _dscFrom) private {
        s_DscMinted[_onBehalfOf] -= _amountToBurn;
        bool success = i_dsc.transferFrom(_dscFrom, address(this), _amountToBurn);
        if(!success){
            revert DSCEngine__DscBurnFailed();
        }
        i_dsc.burn(_amountToBurn);
    }

    function _redeemCollateral(address _tokenCollateral, uint256 _collateralAmount, address _from, address _to) private {
        s_collateralDeposited[_from][_tokenCollateral] -= _collateralAmount;
        emit CollateralRedeemed(_from, _to, _tokenCollateral, _collateralAmount);

        bool success = IERC20(_tokenCollateral).transfer(_to, _collateralAmount);
        if (!success) {
            revert DSCEngine__CollateralRedeemFailed(_tokenCollateral);
        }
    }

////////////////////////////////////////
// Private and internal view Functions//
////////////////////////////////////////
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _calculateHealthFactor(uint256 _totalDscMinted, uint256 _collateralValueInUsd) internal pure returns(uint256){
        if(_totalDscMinted == 0){
            return type(uint256).max;
        }
        uint256 collateralAdjustedThreshold = (_collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedThreshold * PRECISION) / _totalDscMinted;
    }


    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        //console.log("Total DSC minted       ", totalDscMinted);
        //console.log("Collateral value in USD", collateralValueInUsd);
        uint256 healthFactor = _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
        //console.log("Health factor          ", healthFactor);
        return healthFactor;
        
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
            //console.log("User health factor     ", userHealthFactor);
            //console.log("Min health factor      ", MIN_HEALTH_FACTOR);
        if (userHealthFactor <= MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor();
        }
    }

///////////////////////////////////////
// Public and external view Functions//
///////////////////////////////////////
    function getTokenAmountFromUsd(address _token, uint256 usdAmountInWei) public view returns(uint256){
        (, int256 price, , ,) = AggregatorV3Interface(s_priceFeeds[_token]).latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address _user) public view returns(uint256 totalCollateralValueInUsd){
        for(uint256 i= 0; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollateralValueInUsd += getUSDValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function calculateHealthFactor(uint256 _totalDscMinted, uint256 _collateralValueInUsd) external pure returns(uint256){
        return _calculateHealthFactor(_totalDscMinted, _collateralValueInUsd);
    }


    function getUSDValue(address _token, uint256 _amount) public view isAllowedCollateral(_token) returns(uint256){
        (, int256 price, , ,) = AggregatorV3Interface(s_priceFeeds[_token]).latestRoundData();
        //could implement that if !success use another oracle
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * _amount) / PRECISION;
    }

    function getAccountInformation(address user) external view returns (uint256 totalDscMinted, uint256 collateralValueInUsd){
        return _getAccountInformation(user);
    }

    function getCollateralBalanceOfUser(address _user, address _tokenCollateral) external view returns (uint256){
        return s_collateralDeposited[_user][_tokenCollateral];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
