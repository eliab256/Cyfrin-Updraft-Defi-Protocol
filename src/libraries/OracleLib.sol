// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

//import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interface/AggregatorV3Interfsce.sol";
import {AggregatorV3Interface} from "lib/localDependencies/AggregatorV3Interface.sol";

    /*
     * @title OracleLib
     * @author Elia Bordoni
     * @notice This library is used to check the Chainlink Oracle for stale data.
     * If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
     * We want the DSCEngine to freeze if prices become stale.
     * So if the Chainlink network explodes and you have a lot of money locked in the protocol... too bad. 
     */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;
    function stealCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80){
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        //if the price is older than 1 hour, we consider it stale
        if(block.timestamp - updatedAt > 3600){
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}