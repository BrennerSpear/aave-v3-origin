// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveOracle} from '../../../contracts/misc/AaveOracle.sol';
import {IErrors} from '../../interfaces/IErrors.sol';
import {ACLManager} from '../../../contracts/protocol/configuration/ACLManager.sol';
import {IPoolAddressesProvider} from '../../../contracts/interfaces/IPoolAddressesProvider.sol';

contract AaveV3OracleSetupProcedure is IErrors {
    function _setupOracle(
        address oracle,
        address witnetProxy,
        address[] memory assets,
        bytes4[] memory currencyIds
    ) internal {
        if (oracle == address(0)) revert();
        // Set the Witnet proxy
        AaveOracle(oracle).setWitnetProxy(witnetProxy);
        
        // Set the currency IDs for the assets
        if (assets.length > 0 && assets.length == currencyIds.length) {
            AaveOracle(oracle).setAssetCurrencyIds(assets, currencyIds);
        }
    }
} 