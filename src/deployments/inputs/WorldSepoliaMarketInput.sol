// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';
import {DefaultMarketInput} from './DefaultMarketInput.sol';

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

    return (roles, config, flags, deployedContracts);
  }
}
