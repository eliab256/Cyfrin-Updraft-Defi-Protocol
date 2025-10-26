// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IDecentralizedStableCoin is IERC20, IERC20Metadata {
    // Errors
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    // Events from Ownable
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Custom Functions
    function burn(uint256 _amount) external;
    function mint(address _to, uint256 _amount) external returns(bool);

    // ERC20Burnable Functions
    function burnFrom(address account, uint256 value) external;

    // Ownable Functions
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
}