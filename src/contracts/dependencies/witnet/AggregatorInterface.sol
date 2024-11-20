// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorInterface} from "../chainlink/AggregatorInterface.sol";

// First we need the Witnet interface
interface IWitnetPriceRouter {
    /// @notice Gets price and status for a currency pair
    /// @param id The currency pair ID (bytes4)
    /// @return price The current price (with 6 decimals)
    /// @return timestamp When the price was last updated
    /// @return status Status code of the last update
    function valueFor(bytes4 id) external view returns (int256, uint256, uint256);
}

// Then we can create our Chainlink-compatible wrapper
contract WitnetPriceAggregator is AggregatorInterface {
    IWitnetPriceRouter public immutable PRICE_ROUTER;
    bytes4 public immutable CURRENCY_PAIR_ID;

    constructor(address _router, bytes4 _currencyPairId) {
        PRICE_ROUTER = IWitnetPriceRouter(_router);
        CURRENCY_PAIR_ID = _currencyPairId;
    }

    function latestAnswer() external view override returns (int256) {
        (int256 price,,) = PRICE_ROUTER.valueFor(CURRENCY_PAIR_ID);
        return price;
    }

    function latestTimestamp() external view override returns (uint256) {
        (,uint256 timestamp,) = PRICE_ROUTER.valueFor(CURRENCY_PAIR_ID);
        return timestamp;
    }

    // Stub functions to maintain Chainlink compatibility
    function latestRound() external pure override returns (uint256) { return 0; }
    function getAnswer(uint256) external view override returns (int256) {
        (int256 price,,) = PRICE_ROUTER.valueFor(CURRENCY_PAIR_ID);
        return price;
    }
    function getTimestamp(uint256) external view override returns (uint256) {
        (,uint256 timestamp,) = PRICE_ROUTER.valueFor(CURRENCY_PAIR_ID);
        return timestamp;
    }
}
