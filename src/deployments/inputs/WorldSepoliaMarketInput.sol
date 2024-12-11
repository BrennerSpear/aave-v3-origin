// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';
import {DefaultMarketInput} from './DefaultMarketInput.sol';
import {WitnetPriceAdapter} from '../../contracts/dependencies/witnet/WitnetPriceAdapter.sol';

contract WorldSepoliaMarketInput is DefaultMarketInput {
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

    // Override only World Sepolia specific values
    config.marketId = 'Aave V3 World Sepolia Market';
    flags.l2 = true; // World is an L2

    // World Sepolia specific addresses
    config.wrappedNativeToken = 0x4200000000000000000000000000000000000006; // WETH
    // config.l2SequencerUptimeFeed = ;  // only from chainlink, and for now we're using witnet
    config.l2PriceOracleSentinelGracePeriod = 3600; // probably related to sequencer uptime feed, but whatever

    address[] memory assets = new address[](2);
    assets[0] = 0x4200000000000000000000000000000000000006; // WETH
    assets[1] = 0x8803e47fD253915F9c860837f391Aa71B3e03c5A; // WLD

    bytes4[] memory currencyIds = new bytes4[](2);
    currencyIds[0] = 0x3d15f701; // ETH/USD
    currencyIds[1] = 0xa59df722; // WLD/USD

    // World Sepolia specific Oracle config
    config.witnetProxy = 0x1111AbA2164AcdC6D291b08DfB374280035E1111;
    config.oracleDecimals = 6;
    config.assets = assets;
    config.currencyIds = currencyIds;

    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x67f64516DDEC692c1fE956444E1F13E1761E9F2d;
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x67f64516DDEC692c1fE956444E1F13E1761E9F2d;

    return (roles, config, flags, deployedContracts);
  }
}

// world sepolia: https://sepolia.worldscan.org/tokentxns
// eth/usd: 0x3d15f701, 0x4200000000000000000000000000000000000006
// wld/usd: 0xa59df722, 0x8803e47fD253915F9c860837f391Aa71B3e03c5A

// price feed contract:
// 0x1111AbA2164AcdC6D291b08DfB374280035E1111
// source: https://feeds.witnet.io/world/worldchain-sepolia_wld-usd_6 (should be the same for all chains)
