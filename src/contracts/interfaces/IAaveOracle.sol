// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPriceOracleGetter} from './IPriceOracleGetter.sol';
import {IPoolAddressesProvider} from './IPoolAddressesProvider.sol';

/**
 * @title IAaveOracle
 * @author Aave
 * @notice Defines the basic interface for the Aave Oracle
 */
interface IAaveOracle is IPriceOracleGetter {
  /**
   * @dev Emitted after the base currency is set
   * @param baseCurrency The base currency used for price quotes
   * @param baseCurrencyUnit The unit of the base currency
   */
  event BaseCurrencySet(address indexed baseCurrency, uint256 baseCurrencyUnit);

  /**
   * @dev Emitted after the temporary base currency is set
   * @param baseCurrency The temporary base currency
   * @param baseCurrencyUnit The unit of the temporary base currency
   */
  event TemporaryBaseCurrencySet(address indexed baseCurrency, uint256 baseCurrencyUnit);

  /**
   * @dev Emitted after an asset price source is updated
   * @param asset The address of the asset
   * @param source The address of the source
   */
  event AssetSourceUpdated(address indexed asset, address indexed source);

  /**
   * @dev Emitted after the Witnet currency ID for an asset is updated
   * @param asset The address of the asset
   * @param currencyId The Witnet currency ID for the asset
   */
  event AssetCurrencyIdUpdated(address indexed asset, bytes4 indexed currencyId);

  /**
   * @dev Emitted after the Witnet price router is updated
   * @param witnetProxyAddress The address of the Witnet price router
   */
  event WitnetProxyUpdated(address indexed witnetProxyAddress);

  /**
   * @dev Emitted after the address of fallback oracle is updated
   * @param fallbackOracle The address of the fallback oracle
   */
  event FallbackOracleUpdated(address indexed fallbackOracle);

  /**
   * @notice Returns the PoolAddressesProvider
   * @return The address of the PoolAddressesProvider contract
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Sets the fallback oracle
   * @param fallbackOracle The address of the fallback oracle
   */
  function setFallbackOracle(address fallbackOracle) external;

  /**
   * @notice Returns a list of prices from a list of assets addresses
   * @param assets The list of assets addresses
   * @return The prices of the given assets
   */
  function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);

  /**
   * @notice Returns the address of the source for an asset address
   * @param asset The address of the asset
   * @return The address of the source
   */
  function getSourceOfAsset(address asset) external view returns (address);

  /**
   * @notice Returns the address of the fallback oracle
   * @return The address of the fallback oracle
   */
  function getFallbackOracle() external view returns (address);

  /**
   * @notice (deprecated: this is for chainlink, not witnet) Sets the price sources for multiple assets
   * @param assets The addresses of the assets
   * @param sources The addresses of the price sources
   */
  function setAssetSources(address[] calldata assets, address[] calldata sources) external;

  /**
   * @notice Returns the temporary base currency of the oracle
   * @return Address of the temporary base currency
   */
  function temporaryBaseCurrency() external view returns (address);

  /**
   * @notice Returns the temporary base currency unit
   * @return The temporary base currency unit
   */
  function temporaryBaseCurrencyUnit() external view returns (uint256);

  /**
   * @notice Sets the temporary base currency and its unit
   * @param baseCurrency The address of the temporary base currency
   * @param baseCurrencyUnit The unit of the temporary base currency
   */
  function setTemporaryBaseCurrency(address baseCurrency, uint256 baseCurrencyUnit) external;
}
