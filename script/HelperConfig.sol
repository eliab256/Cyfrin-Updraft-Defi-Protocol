//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

abstract contract CodeConstants {
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint8 public constant DECIMALS = 8;
    uint256 public constant ETH_USD_PRICE = 2000e8; // 2000
    uint256 public constant BTC_USD_PRICE = 1000e8; // 1000

}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    //Network Config Struct give different parameters to the contract due to different networks
    struct NetworkConfig {
        address weth;
        address wbtc;
        address wethUsdPriceFeed;
        address btcUsdPriceFeed;
        uint256 deployerkey;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        if (block.chainid == MAINNET_CHAIN_ID) {
            activeNetworkConfig = getEthMainnetConfig();
        } else if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if(block.chainid == ANVIL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }


    function getEthMainnetConfig()public pure returns(NetworkConfig memory){
        return NetworkConfig({
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 ,
            wethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            btcUsdPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            deployerkey: vm.envUint("MAINNET_PRIVATE_KEY")

        });
    }
    function getSepoliaEthConfig()public pure returns(NetworkConfig memory){
        return NetworkConfig({
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            weth:  0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            btcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerkey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed), 
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }



}