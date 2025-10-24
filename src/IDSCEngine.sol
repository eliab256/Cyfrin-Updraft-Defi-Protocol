// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDSCEngine {
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

    function redeemCollateralForDsc() external ;
    
    function redeemCollateralc() external;

    function mintDsc() external;

    function burnDsc() external;

    function liquidate() external;

    function getHealthFactor() external view;
}