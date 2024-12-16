// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IPool} from '../../../src/contracts/interfaces/IPool.sol';
import {IAToken} from '../../../src/contracts/interfaces/IAToken.sol';
import {ISignatureTransfer} from 'permit2/interfaces/ISignatureTransfer.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AavePermit2Router} from '../../../src/contracts/protocol/pool/AavePermit2Router.sol';
import {TestnetERC20} from '../../../src/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {TestnetProcedures} from '../../utils/TestnetProcedures.sol';
import {EIP712SigUtils} from '../../utils/EIP712SigUtils.sol';

contract AavePermit2RouterTest is TestnetProcedures {
  AavePermit2Router internal router;
  ISignatureTransfer internal permit2;
  address internal aUSDX;
  address internal aWBTC;

  // Test user
  address internal user;
  uint256 internal userPrivateKey;

  function setUp() public {
    initTestEnvironment();

    // Setup test user
    userPrivateKey = 0x1234;
    user = vm.addr(userPrivateKey);

    // Get aToken addresses
    (aUSDX, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(tokenList.usdx);
    (aWBTC, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(tokenList.wbtc);

    // Deploy router
    router = new AavePermit2Router(permit2, contracts.poolProxy);
  }

  function test_supplyWithPermit2() public {
    uint256 supplyAmount = 0.2e8;
    deal(tokenList.wbtc, user, supplyAmount);

    // Generate permit2 signature
    bytes memory signature = _getPermit2Signature(
      user,
      address(router),
      tokenList.wbtc,
      supplyAmount,
      0, // nonce
      block.timestamp // deadline
    );

    vm.startPrank(user);

    // Approve Permit2 to spend tokens
    IERC20(tokenList.wbtc).approve(address(permit2), type(uint256).max);

    // Supply with Permit2
    router.supplyWithPermit2(
      tokenList.wbtc,
      supplyAmount,
      user,
      0, // referralCode
      block.timestamp, // deadline
      0, // nonce
      signature
    );

    vm.stopPrank();

    // Verify supply
    assertEq(IERC20(tokenList.wbtc).balanceOf(user), 0);
    assertEq(IAToken(aWBTC).scaledBalanceOf(user), supplyAmount);
  }

  function test_repayWithPermit2() public {
    // First borrow some tokens
    uint256 borrowAmount = 0.1e8;
    _setupBorrowForUser(user, tokenList.wbtc, borrowAmount);

    // Generate permit2 signature for repayment
    bytes memory signature = _getPermit2Signature(
      user,
      address(router),
      tokenList.wbtc,
      borrowAmount,
      0, // nonce
      block.timestamp // deadline
    );

    vm.startPrank(user);

    // Approve Permit2 to spend tokens
    IERC20(tokenList.wbtc).approve(address(permit2), type(uint256).max);

    // Repay with Permit2
    router.repayWithPermit2(
      tokenList.wbtc,
      borrowAmount,
      2, // variable rate mode
      user,
      block.timestamp, // deadline
      0, // nonce
      signature
    );

    vm.stopPrank();

    // Verify repayment
    (
      ,
      ,
      // currentATokenBalance
      // currentStableDebt
      uint256 currentVariableDebt, // currentVariableDebt // principalStableDebt // scaledVariableDebt // stableBorrowRate // liquidityRate // stableRateLastUpdated
      ,
      ,
      ,
      ,
      ,

    ) = // usageAsCollateralEnabled
      contracts.protocolDataProvider.getUserReserveData(tokenList.wbtc, user);
    assertEq(currentVariableDebt, 0);
  }

  function test_revert_supplyWithPermit2_InvalidSignature() public {
    uint256 supplyAmount = 0.2e8;
    deal(tokenList.wbtc, user, supplyAmount);

    // Generate invalid signature (wrong private key)
    bytes memory signature = _getPermit2Signature(
      user,
      address(router),
      tokenList.wbtc,
      supplyAmount,
      0,
      block.timestamp
    );

    vm.startPrank(user);
    IERC20(tokenList.wbtc).approve(address(permit2), type(uint256).max);

    vm.expectRevert('INVALID_SIGNATURE');
    router.supplyWithPermit2(tokenList.wbtc, supplyAmount, user, 0, block.timestamp, 0, signature);

    vm.stopPrank();
  }

  function test_revert_repayWithPermit2_InvalidAmount() public {
    uint256 borrowAmount = 0.1e8;
    _setupBorrowForUser(user, tokenList.wbtc, borrowAmount);

    // Try to repay more than borrowed
    bytes memory signature = _getPermit2Signature(
      user,
      address(router),
      tokenList.wbtc,
      borrowAmount * 2,
      0,
      block.timestamp
    );

    vm.startPrank(user);
    IERC20(tokenList.wbtc).approve(address(permit2), type(uint256).max);

    vm.expectRevert('INVALID_AMOUNT');
    router.repayWithPermit2(
      tokenList.wbtc,
      borrowAmount * 2,
      2,
      user,
      block.timestamp,
      0,
      signature
    );

    vm.stopPrank();
  }

  // Helper function to generate Permit2 signatures
  function _getPermit2Signature(
    address from,
    address to,
    address token,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes memory) {
    bytes32 permit2TypeHash = keccak256(
      'PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
    );

    bytes32 tokenPermissionsHash = keccak256(
      abi.encode(keccak256('TokenPermissions(address token,uint256 amount)'), token, amount)
    );

    bytes32 structHash = keccak256(
      abi.encode(permit2TypeHash, tokenPermissionsHash, to, nonce, deadline)
    );

    bytes32 digest = keccak256(
      abi.encodePacked('\x19\x01', permit2.DOMAIN_SEPARATOR(), structHash)
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
    return abi.encodePacked(r, s, v);
  }

  // Helper function to setup a borrow position for testing repayment
  function _setupBorrowForUser(address _user, address _asset, uint256 _amount) internal {
    // Supply collateral
    deal(tokenList.usdx, _user, _amount * 2);
    vm.startPrank(_user);
    IERC20(tokenList.usdx).approve(address(contracts.poolProxy), type(uint256).max);
    contracts.poolProxy.supply(tokenList.usdx, _amount * 2, _user, 0);

    // Borrow asset
    contracts.poolProxy.borrow(_asset, _amount, 2, 0, _user);
    vm.stopPrank();

    // Provide tokens for repayment
    deal(_asset, _user, _amount);
  }
}
