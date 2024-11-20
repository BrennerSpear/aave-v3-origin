// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';
import {DefaultMarketInput} from './DefaultMarketInput.sol';

contract BaseSepoliaMarketInput is DefaultMarketInput {
    function _getMarketInput(
        address deployer
    )
        internal
        pure
        override
        returns (
            Roles memory roles,
            MarketConfig memory config,
            DeployFlags memory flags,
            MarketReport memory deployedContracts
        )
    {
        // Get default values first
        (roles, config, flags, deployedContracts) = super._getMarketInput(deployer);

        // Override only Base Sepolia specific values
        config.marketId = "Aave V3 Base Sepolia Market";
        flags.l2 = true;  // Base is an L2
        
        // Base Sepolia specific addresses
        config.wrappedNativeToken = 0x4200000000000000000000000000000000000006; // WETH
        config.l2SequencerUptimeFeed = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
        config.l2PriceOracleSentinelGracePeriod = 3600;

        return (roles, config, flags, deployedContracts);
    }
}