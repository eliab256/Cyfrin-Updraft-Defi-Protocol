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

    DecentralizedStableCoin public immutable i_dsc;
    mapping(address => address) private s_priceFeeds;
    mapping(address => mapping(address => uint256)) private s_collateralDeposited;

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

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
