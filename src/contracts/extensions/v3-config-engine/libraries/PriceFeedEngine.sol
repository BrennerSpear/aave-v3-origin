// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IAaveV3ConfigEngine as IEngine, IAaveOracle} from '../IAaveV3ConfigEngine.sol';
import {IEACAggregatorProxy} from '../../../helpers/interfaces/IEACAggregatorProxy.sol';

library PriceFeedEngine {
  // TODO WARNING this doesn't do anything anymore, I hope we don't ever use it...
  function executePriceFeedsUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.PriceFeedUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _setPriceFeeds(engineConstants.oracle, updates);
  }

  function _setPriceFeeds(IAaveOracle oracle, IEngine.PriceFeedUpdate[] memory updates) internal {
    address[] memory assets = new address[](updates.length);
    address[] memory sources = new address[](updates.length);

    for (uint256 i = 0; i < updates.length; i++) {
      require(updates[i].priceFeed != address(0), 'PRICE_FEED_ALWAYS_REQUIRED');
      require(
        IEACAggregatorProxy(updates[i].priceFeed).latestAnswer() > 0,
        'FEED_SHOULD_RETURN_POSITIVE_PRICE'
      );
      assets[i] = updates[i].asset;
      sources[i] = updates[i].priceFeed;
    }

    // we don't use chainlink anymore
    // oracle.setAssetSources(assets, sources);
  }
}
