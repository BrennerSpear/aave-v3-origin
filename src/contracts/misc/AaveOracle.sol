// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WitnetProxyInterface, WitnetPrice} from '../dependencies/witnet/WitnetPriceRouterInterface.sol';
import {Errors} from '../protocol/libraries/helpers/Errors.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '../interfaces/IPoolAddressesProvider.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';
import {IAaveOracle} from '../interfaces/IAaveOracle.sol';

/**
 * @title AaveOracle
 * @author Aave
 * @notice Contract to get asset prices, manage price sources and update the fallback oracle
 * - Uses Witnet Price Router as primary source of prices
 * - If the returned price by Witnet is <= 0, the call is forwarded to a fallback oracle
 * - Owned by the Aave governance
 */
contract AaveOracle is IAaveOracle {
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  WitnetProxyInterface public witnetProxy;

  // Map of asset to Witnet currency pair ID
  mapping(address => bytes4) private assetToCurrencyId;

  IPriceOracleGetter private _fallbackOracle;
  address public immutable override BASE_CURRENCY;
  uint256 public immutable override BASE_CURRENCY_UNIT;
  address public override temporaryBaseCurrency;
  uint256 public override temporaryBaseCurrencyUnit;

  /**
   * @dev Only asset listing or pool admin can call functions marked by this modifier.
   */
  modifier onlyAssetListingOrPoolAdmins() {
    _onlyAssetListingOrPoolAdmins();
    _;
  }

  /**
   * @notice Constructor
   * @param provider The address of the new PoolAddressesProvider
   * @param assets The addresses of the assets
   * @param sources DEPRECATED - kept for interface compatibility
   * @param fallbackOracle The address of the fallback oracle to use if the Witnet price
   *        is not available or invalid
   * @param baseCurrency The base currency used for the price quotes. If USD is used, base currency is 0x0
   * @param baseCurrencyUnit The unit of the base currency
   */
  constructor(
    IPoolAddressesProvider provider,
    address[] memory assets,
    address[] memory sources,
    address fallbackOracle,
    address baseCurrency,
    uint256 baseCurrencyUnit
  ) {
    ADDRESSES_PROVIDER = provider;
    _setFallbackOracle(fallbackOracle);
    BASE_CURRENCY = baseCurrency;
    BASE_CURRENCY_UNIT = baseCurrencyUnit;
    emit BaseCurrencySet(baseCurrency, baseCurrencyUnit);
  }

  /// @inheritdoc IAaveOracle
  function setFallbackOracle(
    address fallbackOracle
  ) external override onlyAssetListingOrPoolAdmins {
    _setFallbackOracle(fallbackOracle);
  }

  /**
   * @notice Sets or updates the Witnet price router address
   * @param witnetProxyAddress The address of the Witnet price router contract
   */
  function setWitnetProxy(address witnetProxyAddress) external onlyAssetListingOrPoolAdmins {
    _setWitnetProxy(witnetProxyAddress);
  }

  /**
   * @notice Internal function to set the Witnet price router
   * @param witnetProxyAddress The address of the Witnet price router contract
   */
  function _setWitnetProxy(address witnetProxyAddress) internal {
    witnetProxy = WitnetProxyInterface(witnetProxyAddress);
    emit WitnetProxyUpdated(witnetProxyAddress);
  }

  function setTemporaryBaseCurrency(
    address baseCurrency,
    uint256 baseCurrencyUnit
  ) external onlyAssetListingOrPoolAdmins {
    _setTemporaryBaseCurrency(baseCurrency, baseCurrencyUnit);
  }

  /**
   * @notice Internal function to set the temporary base currency
   * @param baseCurrency The address of the temporary base currency
   * @param baseCurrencyUnit The unit of the temporary base currency
   */
  function _setTemporaryBaseCurrency(address baseCurrency, uint256 baseCurrencyUnit) internal {
    temporaryBaseCurrency = baseCurrency;
    temporaryBaseCurrencyUnit = baseCurrencyUnit;
    emit TemporaryBaseCurrencySet(baseCurrency, baseCurrencyUnit);
  }

  /**
   * @notice Sets or updates the Witnet currency IDs for given assets
   * @param assets The addresses of the assets to update
   * @param currencyIds The Witnet currency IDs for each asset (e.g., "Price-WLD/USD-6" -> 0xa59df722)
   */
  function setAssetCurrencyIds(
    address[] calldata assets,
    bytes4[] calldata currencyIds
  ) external onlyAssetListingOrPoolAdmins {
    _setAssetsCurrencyIds(assets, currencyIds);
  }

  /**
   * @notice Internal function to set the currency ids for each asset
   * @param assets The addresses of the assets
   * @param currencyIds The currency ids of each asset (example: Price-WLD/USD-6 -> a59df722)
   */
  function _setAssetsCurrencyIds(address[] memory assets, bytes4[] memory currencyIds) internal {
    for (uint256 i = 0; i < assets.length; i++) {
      assetToCurrencyId[assets[i]] = currencyIds[i];
      emit AssetCurrencyIdUpdated(assets[i], currencyIds[i]);
    }
  }

  /**
   * @notice Internal function to set the fallback oracle
   * @param fallbackOracle The address of the fallback oracle
   */
  function _setFallbackOracle(address fallbackOracle) internal {
    _fallbackOracle = IPriceOracleGetter(fallbackOracle);
    emit FallbackOracleUpdated(fallbackOracle);
  }

  /**
   * @notice Returns the price of the given asset
   * @param asset The address of the asset
   * @return The price of the asset from Witnet price router, or fallback oracle if Witnet
   *         price is unavailable or invalid. Returns BASE_CURRENCY_UNIT if asset is BASE_CURRENCY
   *         or temporaryBaseCurrencyUnit if asset is temporaryBaseCurrency
   */
  function getAssetPrice(address asset) public view override returns (uint256) {
    bytes4 currencyId = assetToCurrencyId[asset];

    if (asset == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    } else if (asset == temporaryBaseCurrency && temporaryBaseCurrency != address(0)) {
      return temporaryBaseCurrencyUnit;
    } else if (currencyId == bytes4(0)) {
      return _fallbackOracle.getAssetPrice(asset);
    } else {
      WitnetPrice memory price = witnetProxy.latestPrice(currencyId);
      if (price.value > 0) {
        return uint256(price.value);
      } else {
        return _fallbackOracle.getAssetPrice(asset);
      }
    }
  }

  /**
   * @notice Returns prices for a list of assets using Witnet's batch price fetching
   * @param assets Array of asset addresses
   * @return Array of prices corresponding to the assets. Uses fallback oracle for any
   *         assets without valid Witnet prices
   */
  function getAssetsPrices(
    address[] calldata assets
  ) external view override returns (uint256[] memory) {
    uint256[] memory prices = new uint256[](assets.length);
    bytes4[] memory currencyIds = new bytes4[](assets.length);

    // First collect all currency IDs
    for (uint256 i = 0; i < assets.length; i++) {
      if (assets[i] == BASE_CURRENCY) {
        prices[i] = BASE_CURRENCY_UNIT;
      } else if (assets[i] == temporaryBaseCurrency && temporaryBaseCurrency != address(0)) {
        prices[i] = temporaryBaseCurrencyUnit;
      } else {
        currencyIds[i] = assetToCurrencyId[assets[i]];
      }
    }

    // Batch fetch prices from Witnet
    WitnetPrice[] memory witnetPrices = witnetProxy.latestPrices(currencyIds);

    // Process results
    for (uint256 i = 0; i < assets.length; i++) {
      if (assets[i] != BASE_CURRENCY && assets[i] != temporaryBaseCurrency) {
        if (currencyIds[i] == bytes4(0) || witnetPrices[i].value <= 0) {
          // Use fallback if no Witnet price or invalid price
          prices[i] = _fallbackOracle.getAssetPrice(assets[i]);
        } else {
          prices[i] = witnetPrices[i].value;
        }
      }
    }

    return prices;
  }

  /**
   * @notice Returns the address of the price source for an asset
   * @param asset The address of the asset
   * @return The address of the Witnet price router
   */
  function getSourceOfAsset(address asset) external view override returns (address) {
    return address(witnetProxy);
  }

  /// @inheritdoc IAaveOracle
  function getFallbackOracle() external view returns (address) {
    return address(_fallbackOracle);
  }

  function setAssetSources(address[] calldata, address[] calldata) external override {}

  function _onlyAssetListingOrPoolAdmins() internal view {
    IACLManager aclManager = IACLManager(ADDRESSES_PROVIDER.getACLManager());
    require(
      aclManager.isAssetListingAdmin(msg.sender) || aclManager.isPoolAdmin(msg.sender),
      Errors.CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN
    );
  }
}
