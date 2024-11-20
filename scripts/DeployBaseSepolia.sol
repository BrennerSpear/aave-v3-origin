// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeployAaveV3MarketBatchedBase} from './misc/DeployAaveV3MarketBatchedBase.sol';

import {BaseSepoliaMarketInput} from '../src/deployments/inputs/BaseSepoliaMarketInput.sol';

contract Deploy is DeployAaveV3MarketBatchedBase, BaseSepoliaMarketInput {}
