// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IEACAggregatorProxy} from '../../helpers/interfaces/IEACAggregatorProxy.sol';
import {WitnetProxyInterface, WitnetPrice, WitnetResponseStatus} from './WitnetPriceRouterInterface.sol';

/**
 * @title WitnetPriceAdapter
 * @notice Adapter contract that implements Chainlink's IEACAggregatorProxy interface
 * but uses Witnet price feeds internally. This allows Witnet price feeds to be used
 * in place of Chainlink price feeds in the Aave protocol.
 */
contract WitnetPriceAdapter is IEACAggregatorProxy {
    WitnetProxyInterface public immutable witnetProxy;
    bytes4 public immutable currencyId;
    uint8 private immutable _decimals;

    error PriceFeedNotReady();
    error InvalidPrice();

    constructor(
        address _witnetProxy,
        bytes4 _currencyId,
        uint8 decimalsValue
    ) {
        witnetProxy = WitnetProxyInterface(_witnetProxy);
        currencyId = _currencyId;
        _decimals = decimalsValue;
    }

    /// @inheritdoc IEACAggregatorProxy
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IEACAggregatorProxy
    function latestAnswer() external view returns (int256) {
        WitnetPrice memory price = witnetProxy.latestPrice(currencyId);
        
        // Check if price feed is ready
        if (price.status != WitnetResponseStatus.Ready) {
            revert PriceFeedNotReady();
        }

        // Convert uint256 to int256, checking for overflow
        if (price.value > uint256(type(int256).max)) {
            revert InvalidPrice();
        }

        return int256(price.value);
    }

    /// @inheritdoc IEACAggregatorProxy
    function latestTimestamp() external view returns (uint256) {
        WitnetPrice memory price = witnetProxy.latestPrice(currencyId);
        return price.timestamp;
    }

    /// @inheritdoc IEACAggregatorProxy
    function latestRound() external view returns (uint256) {
        // Witnet doesn't have the concept of rounds, so we use the timestamp
        WitnetPrice memory price = witnetProxy.latestPrice(currencyId);
        return price.timestamp;
    }

    /// @inheritdoc IEACAggregatorProxy
    function getAnswer(uint256 roundId) external view returns (int256) {
        // Since Witnet doesn't store historical prices, we can only return the latest
        // This maintains interface compatibility while gracefully degrading functionality
        return this.latestAnswer();
    }

    /// @inheritdoc IEACAggregatorProxy
    function getTimestamp(uint256 roundId) external view returns (uint256) {
        // Since Witnet doesn't store historical prices, we can only return the latest
        return this.latestTimestamp();
    }
}
