// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';
import {WitnetPriceAdapter} from '../src/contracts/dependencies/witnet/WitnetPriceAdapter.sol';

contract Deploy is Script {
    function run() external {
        console2.log('Deploying Witnet Price Adapter');
        console2.log('sender', msg.sender);

        // World Sepolia Witnet proxy
        address witnetProxy = 0x1111AbA2164AcdC6D291b08DfB374280035E1111;
        // ETH/USD currency ID
        bytes4 currencyId = 0x3d15f701;
        // Witnet uses 6 decimals for price feeds
        uint8 decimals = 6;

        vm.startBroadcast();
        WitnetPriceAdapter adapter = new WitnetPriceAdapter(
            witnetProxy,
            currencyId,
            decimals
        );
        vm.stopBroadcast();

        console2.log('Deployed WitnetPriceAdapter at:', address(adapter));
    }
}
