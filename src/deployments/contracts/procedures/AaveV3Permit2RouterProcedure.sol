// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPool} from '../../../contracts/interfaces/IPool.sol';
import {AavePermit2Router} from '../../../contracts/protocol/pool/AavePermit2Router.sol';
import {ISignatureTransfer} from 'permit2/interfaces/ISignatureTransfer.sol';
import {IPoolAddressesProvider} from '../../../contracts/interfaces/IPoolAddressesProvider.sol';
import {IErrors} from '../../interfaces/IErrors.sol';

contract AaveV3Permit2RouterProcedure is IErrors {
  function _deployPermit2Router(address addressesProvider) internal returns (address) {
    if (addressesProvider == address(0)) revert ProviderNotFound();

    // Deploy and initialize implementation
    address routerImpl = _deployPermit2RouterImpl(addressesProvider);

    return routerImpl;
  }

  function _deployPermit2RouterImpl(address addressesProvider) internal returns (address) {
    // Deploy implementation with AddressesProvider
    address router = address(new AavePermit2Router(IPoolAddressesProvider(addressesProvider)));

    // Initialize implementation
    AavePermit2Router(router).initialize(IPoolAddressesProvider(addressesProvider));

    return router;
  }
}
