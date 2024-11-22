// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IWrappedTokenGatewayV3} from "../src/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";
import {IPool} from "../src/contracts/interfaces/IPool.sol";
import {DataTypes} from '../src/contracts/protocol/libraries/types/DataTypes.sol';

// WETH interface
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

// ERC20 interface just for approve
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DebugGatewayScript is Script {
    // Update this with your World Sepolia gateway address
    address public constant GATEWAY = 0x020F19f46F9A353AfF36Ab9d30A6E96141f88402; 
    address public constant POOL_PROXY = 0x25Dd92c22d1230e8D85D5e344D0FAA5303861975; 
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant WLD = 0x8803e47fD253915F9c860837f391Aa71B3e03c5A;

    function depositEth() public {
        try IWrappedTokenGatewayV3(GATEWAY).depositETH{value: 0.01 ether}(
                    POOL_PROXY,
                    msg.sender, // onBehalfOf
                    0 // referralCode
                ) {
                    console.log("Success!");
                } catch (bytes memory returnData) {
                    console.logBytes(returnData);
                }
    }

    function wrapEth(uint256 amount) internal {
        // Get WETH contract interface and check initial balance
        IWETH weth = IWETH(WETH);
        uint256 balanceBefore = weth.balanceOf(msg.sender);
        console.log("WETH Balance Before:", balanceBefore);
        
        weth.deposit{value: amount}();
        
        // Log the final balance
        uint256 balanceAfter = weth.balanceOf(msg.sender);
        console.log("WETH Balance After:", balanceAfter);
        console.log("WETH Received:", balanceAfter - balanceBefore);
    }

    function depositWeth(uint256 amount) internal {
        IWETH weth = IWETH(WETH);
        
        // First approve the pool to spend our WETH
        weth.approve(POOL_PROXY, amount);
        
        // Supply WETH to the pool
        IPool(POOL_PROXY).supply(
            WETH,      // asset
            amount,    // amount
            msg.sender, // onBehalfOf
            0          // referralCode
        );
        
        console.log("Successfully supplied", amount, "WETH to Aave pool");
    }

    function lendWld(uint256 amount) internal {
        // First approve the pool to spend our WLD
        IERC20(WLD).approve(POOL_PROXY, amount);
        
        // Supply WLD to the pool
        IPool(POOL_PROXY).supply(
            WLD,       // asset
            amount,    // amount
            msg.sender, // onBehalfOf
            0          // referralCode
        );
        
        console.log("Successfully supplied", amount, "WLD to Aave pool");
    }

    function borrowWld(uint256 amount) internal {
        // Borrow WLD from the pool
        IPool(POOL_PROXY).borrow(
            WLD,       // asset
            amount,    // amount
            2,         // interestRateMode (2 for variable)
            0,         // referralCode
            msg.sender // onBehalfOf
        );
        
        console.log("Successfully borrowed", amount, "WLD from Aave pool");
    }

    function checkWethPool() public {
        // Check if WETH is listed in pool
        try IPool(POOL_PROXY).getReserveData(WETH) returns (
            DataTypes.ReserveDataLegacy memory data
        ) {
            console.log("Success! WETH is listed in pool");
            console.log("WETH aToken:", data.aTokenAddress);
            console.log("WETH variable debt token:", data.variableDebtTokenAddress);
        } catch (bytes memory returnData) {
            console.logBytes(returnData);
        }
    }

    function run() external {
        vm.startBroadcast();

        console.log("ETH Balance Before:", msg.sender.balance);
        console.log("Gateway Address:", GATEWAY);
        
        // depositEth();
        // First wrap ETH to WETH
        // wrapEth(1 ether);
        
        // Then deposit WETH to Aave
        // depositWeth(0.1 ether);

        // Borrow 1 WLD
        borrowWld(1 ether);

        // lendWld(1000 ether);

        console.log("ETH Balance After:", msg.sender.balance);

        vm.stopBroadcast();
    }
} 