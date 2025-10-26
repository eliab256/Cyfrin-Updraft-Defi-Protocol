// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IDSCEngine {
    // ----------- Errors -----------
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

    // ----------- Events -----------
    event CollateralDeposited(
        address indexed depositer,
        address indexed tokenCollateral,
        uint256 indexed collateralAmount
    );

    event CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeemTo,
        address indexed tokenCollateral,
        uint256 collateralAmount
    );

    // ----------- External Function -----------

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToMint: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(address _tokenCollateralAddress, uint256 _collateralAmount) external;

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address _tokenCollateralAddress, uint256 _collateralAmount) external;

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're withdrawing
     * @param amountCollateral: The amount of collateral you're withdrawing
     * @param amountDscToBurn: The amount of DSC you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */
    function redeemCollateralForDsc() external;

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
     */
    function redeemCollateral() external;

    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you have enough collateral
     */
    function mintDsc() external;

    /*
     * @notice careful! You'll burn your DSC here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * your DSC but keep your collateral in.
     */
    function burnDsc() external;

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this
       to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate
       anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate() external;

    // ----------- View Functions -----------
    function getTokenAmountFromUsd(address _token, uint256 usdAmountInWei) external view returns(uint256);
    
    function getAccountCollateralValue(address _user) external view returns(uint256 totalCollateralValueInUsd);
    
    function calculateHealthFactor(uint256 _totalDscMinted, uint256 _collateralValueInUsd) external pure returns(uint256);
    
    function getUSDValue(address _token, uint256 _amount) external view returns(uint256);
    
    function getAccountInformation(address user) external view returns (uint256 totalDscMinted, uint256 collateralValueInUsd);
    
    function getCollateralBalanceOfUser(address _user, address _tokenCollateral) external view returns (uint256);
    
    function getPrecision() external pure returns (uint256);
    
    function getAdditionalFeedPrecision() external pure returns (uint256);
    
    function getLiquidationThreshold() external pure returns (uint256);
    
    function getLiquidationBonus() external pure returns (uint256);
    
    function getLiquidationPrecision() external pure returns (uint256);
    
    function getMinHealthFactor() external pure returns (uint256);
    
    function getCollateralTokens() external view returns (address[] memory);
    
    function getDsc() external view returns (address);
    
    function getCollateralTokenPriceFeed(address token) external view returns (address);
    
    function getHealthFactor(address user) external view returns (uint256);

    // ----------- Public State Variables (automatically generate getters) ----------- 
    function i_dsc() external view returns (address);
    
    function s_priceFeeds(address token) external view returns (address priceFeed);
    
    function ADDITIONAL_FEED_PRECISION() external pure returns (uint256);
    
    function PRECISION() external pure returns (uint256);
    
    function LIQUIDATION_THRESHOLD() external pure returns (uint256);
    
    function LIQUIDATION_PRECISION() external pure returns (uint256);
    
    function LIQUIDATION_BONUS() external pure returns (uint256);
    
    function MIN_HEALTH_FACTOR() external pure returns (uint256);
}
