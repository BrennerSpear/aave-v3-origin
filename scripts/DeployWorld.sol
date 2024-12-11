// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeployAaveV3MarketBatchedBase} from './misc/DeployAaveV3MarketBatchedBase.sol';

import {WorldMarketInput} from '../src/deployments/inputs/WorldMarketInput.sol';

contract Deploy is DeployAaveV3MarketBatchedBase, WorldMarketInput {}
