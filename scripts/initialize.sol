// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';
import {IPoolConfigurator} from '../src/contracts/interfaces/IPoolConfigurator.sol';
import {IPoolAddressesProvider} from '../src/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from '../src/contracts/interfaces/IPool.sol';
import {DataTypes} from '../src/contracts/protocol/libraries/types/DataTypes.sol';
import {ConfiguratorInputTypes} from '../src/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {DefaultReserveInterestRateStrategyV2} from '../src/contracts/misc/DefaultReserveInterestRateStrategyV2.sol';
import {IDefaultInterestRateStrategyV2} from '../src/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {IACLManager} from '../src/contracts/interfaces/IACLManager.sol';

contract ConfigureWorldSepoliaPool is Script {
    // Pool addresses - replace with actual deployed addresses
    address constant POOL_ADDRESSES_PROVIDER = 0x277ce103Df38dE77d96E68C57aC9c7D2fc95502b;
    
    // Asset addresses from WorldSepoliaMarketInput
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WLD = 0x8803e47fD253915F9c860837f391Aa71B3e03c5A;

    // Implementation addresses
    address constant ATOKEN_IMPL = 0x98137DBFd4e72C2D15A951941704e0AA9E205e5C;
    address constant VARIABLE_DEBT_TOKEN_IMPL = 0x54ce04aFf2d672BA2a8D66E667845eE4071583C0;
    address constant STABLE_DEBT_TOKEN_IMPL = address(0); // disabled for initial launch

    // Common parameters for interest rate strategy
    uint256 constant OPTIMAL_USAGE_RATIO = 80_00; // 80%
    address constant TREASURY = 0x11fb3d20AFd7f25368eb078D1Ce8Bfbdf35ca485;

    // Report structure to track deployments
    struct DeploymentReport {
        address wethStrategy;
        address wldStrategy;
    }

    function run() external {
        // Get configurator address before broadcast
        IPoolAddressesProvider provider = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
        address configuratorAddress = provider.getPoolConfigurator();
        address aclManager = provider.getACLManager();
        
        vm.startBroadcast();

        // Set up roles
        IACLManager(aclManager).addPoolAdmin(msg.sender);
        IACLManager(aclManager).addAssetListingAdmin(msg.sender);

        // Initialize report in memory
        DeploymentReport memory report;

        IPoolConfigurator configurator = IPoolConfigurator(configuratorAddress);
        IPool pool = IPool(provider.getPool());

        // Deploy interest rate strategies
        DefaultReserveInterestRateStrategyV2 wethStrategy = new DefaultReserveInterestRateStrategyV2(
            address(provider)
        );
        report.wethStrategy = address(wethStrategy);

        DefaultReserveInterestRateStrategyV2 wldStrategy = new DefaultReserveInterestRateStrategyV2(
            address(provider)
        );
        report.wldStrategy = address(wldStrategy);

        // Initialize WETH Reserve with interest rate params
        ConfiguratorInputTypes.InitReserveInput[] memory wethInput = new ConfiguratorInputTypes.InitReserveInput[](1);
        wethInput[0] = ConfiguratorInputTypes.InitReserveInput({
            aTokenImpl: ATOKEN_IMPL,
            variableDebtTokenImpl: VARIABLE_DEBT_TOKEN_IMPL,
            useVirtualBalance: false,
            interestRateStrategyAddress: address(wethStrategy),
            underlyingAsset: WETH,
            treasury: TREASURY,
            incentivesController: address(0),
            aTokenName: 'Aave World Sepolia WETH',
            aTokenSymbol: 'aWETH',
            variableDebtTokenName: 'Aave World Sepolia Variable Debt WETH',
            variableDebtTokenSymbol: 'variableDebtWETH',
            params: '',
            interestRateData: abi.encode(IDefaultInterestRateStrategyV2.InterestRateData({
                optimalUsageRatio: uint16(OPTIMAL_USAGE_RATIO),
                baseVariableBorrowRate: 0,
                variableRateSlope1: 700,
                variableRateSlope2: 30000
            }))
        });

        // Initialize WLD Reserve with interest rate params
        ConfiguratorInputTypes.InitReserveInput[] memory wldInput = new ConfiguratorInputTypes.InitReserveInput[](1);
        wldInput[0] = ConfiguratorInputTypes.InitReserveInput({
            aTokenImpl: ATOKEN_IMPL,
            variableDebtTokenImpl: VARIABLE_DEBT_TOKEN_IMPL,
            useVirtualBalance: false,
            interestRateStrategyAddress: address(wldStrategy),
            underlyingAsset: WLD,
            treasury: TREASURY,
            incentivesController: address(0),
            aTokenName: 'Aave World Sepolia WLD',
            aTokenSymbol: 'aWLD',
            variableDebtTokenName: 'Aave World Sepolia Variable Debt WLD',
            variableDebtTokenSymbol: 'variableDebtWLD',
            params: '',
            interestRateData: abi.encode(IDefaultInterestRateStrategyV2.InterestRateData({
                optimalUsageRatio: uint16(OPTIMAL_USAGE_RATIO),
                baseVariableBorrowRate: 0,
                variableRateSlope1: 1000,
                variableRateSlope2: 30000
            }))
        });

        // Initialize reserves
        configurator.initReserves(wethInput);
        configurator.initReserves(wldInput);

        // Configure WETH risk parameters
        configurator.configureReserveAsCollateral(
            WETH,
            70_00, // LTV 70%
            75_00, // Liquidation threshold 75%
            105_00 // Liquidation bonus 5%
        );
        configurator.setReserveFactor(WETH, 10_00); // 10% reserve factor
        configurator.setSupplyCap(WETH, 100_000); // 100k WETH supply cap
        configurator.setBorrowCap(WETH, 80_000); // 80k WETH borrow cap
        configurator.setReserveBorrowing(WETH, true); // Enable borrowing

        // Configure WLD risk parameters
        configurator.configureReserveAsCollateral(
            WLD,
            70_00, // LTV 70%
            75_00, // Liquidation threshold 75%
            110_00 // Liquidation bonus 10%
        );
        configurator.setReserveFactor(WLD, 20_00); // 20% reserve factor
        configurator.setSupplyCap(WLD, 1_000_000); // 1M WLD supply cap
        configurator.setBorrowCap(WLD, 800_000); // 800k WLD borrow cap
        configurator.setReserveBorrowing(WLD, true); // Enable borrowing

        vm.stopBroadcast();

        // Report deployment
        console2.log('========================');
        console2.log('Deployment Report');
        console2.log('========================');
        console2.log('Interest Rate Strategies:');
        console2.log('- WETH:', report.wethStrategy);
        console2.log('- WLD:', report.wldStrategy);
        console2.log('========================');
        console2.log('Initialized Reserves:');
        console2.log('- WETH: true');
        console2.log('- WLD: true');
        console2.log('========================');
    }
}