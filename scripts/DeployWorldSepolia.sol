// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeployAaveV3MarketBatchedBase} from './misc/DeployAaveV3MarketBatchedBase.sol';

import {WorldSepoliaMarketInput} from '../src/deployments/inputs/WorldSepoliaMarketInput.sol';

contract Deploy is DeployAaveV3MarketBatchedBase, WorldSepoliaMarketInput {}
