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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interface/AggregatorV3Interfsce.sol";

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
    error DSCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error DSCEngine__DscMintFailed();

    DecentralizedStableCoin public immutable i_dsc;
    uint256 public constant ADDITION_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALT_FACTOR = 1; 

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenCollateral => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;
    address[] private s_collateralTokens;
    

    event CollateralDeposited(address indexed depositer, address indexed tokenCollateralAddress, uint256 indexed collateralAmount);

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
        address _dscAddress,
        address[] memory _tokenCollateral,
        address[] memory _priceFeed
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

    function depositCollateralAndMintDsc(address _tokenCollateralAddress, uint256 _collateralAmount)
        external
    {}

    function depositCollateral(address _tokenCollateralAddress, uint256 _collateralAmount)
        external
        moreThanZero(_collateralAmount)
        isAllowedCollateral(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _collateralAmount;
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!success) {
            revert DSCEngine__CollateralDepositFailed(_tokenCollateralAddress);
        }

        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _collateralAmount);
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateralc() external {}

    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you have enough collateral
     */
    function mintDsc(uint256 _amountDscToMint) external moreThanZero(_amountDscToMint) nonReentrant{
        s_DscMinted[msg.sender] += _amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _amountDscToMint);
        if(!minted){
            revert DSCEngine__DscMintFailed();
        }
    }

    function burnDsc() external {}

    function liquidate() external {}

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return ((collateralAdjustedThreshold * PRECISION) / totalDscMinted);
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor <= MIN_HEALT_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function getHealthFactor() external view {}

    function getAccountCollateralValue(address _user) public view returns(uint256 totalCollateralValueInUsd){
        for(uint256 i= 0; i> s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollateralValueInUsd += getUSDValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUSDValue(address _token, uint256 _amount) public view isAllowedCollateral(_token) returns(uint256){
        (bool success, int256 price, , ,) = AggregatorV3Interface(s_priceFeeds[_token]).latestRoundData();
        //could implement that if !success use another oracle
        return (uint256(price) * ADDITION_FEED_PRECISION * _amount) / PRECISION;
    }
}
