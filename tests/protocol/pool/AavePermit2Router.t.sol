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
import {MockPermit2} from '../../mocks/MockPermit2.sol';

contract AavePermit2RouterTest is TestnetProcedures {
  address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  AavePermit2Router internal router;
  ISignatureTransfer internal permit2;
  address internal aUSDX;
  address internal aWBTC;

  uint256 internal userPrivateKey;
  address internal user;

  function setUp() public virtual {
    super.initL2TestEnvironment();
    // Setup test user
    userPrivateKey = 0x12345678; // Use a proper private key for testing
    user = vm.addr(userPrivateKey);

    // Get aToken addresses from protocol data provider
    (address aTokenAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.usdx
    );
    aUSDX = aTokenAddress;
    (aTokenAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(tokenList.wbtc);
    aWBTC = aTokenAddress;

    // Deploy mock Permit2
    MockPermit2 permit2Contract = new MockPermit2();
    vm.etch(PERMIT2_ADDRESS, address(permit2Contract).code);
    permit2 = ISignatureTransfer(PERMIT2_ADDRESS);

    // Use deployed router
    router = AavePermit2Router(contracts.permit2Router);
  }

  function test_supplyWithPermit2() public {
    uint256 supplyAmount = 0.1e8;
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

    // Approve tokens for pool
    IERC20(tokenList.wbtc).approve(address(contracts.poolProxy), type(uint256).max);
    // Approve tokens for Permit2
    IERC20(tokenList.wbtc).approve(PERMIT2_ADDRESS, type(uint256).max);

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
    uint256 borrowAmount = 1e6; // 1 WBTC
    deal(tokenList.wbtc, user, borrowAmount);

    vm.startPrank(user);

    // Approve tokens for pool
    IERC20(tokenList.wbtc).approve(address(contracts.poolProxy), type(uint256).max);
    // Approve tokens for Permit2
    IERC20(tokenList.wbtc).approve(PERMIT2_ADDRESS, type(uint256).max);

    // First supply some collateral
    uint256 collateralAmount = 20e6; // 20 USDX
    deal(tokenList.usdx, user, collateralAmount);
    IERC20(tokenList.usdx).approve(address(contracts.poolProxy), type(uint256).max);
    contracts.poolProxy.supply(tokenList.usdx, collateralAmount, user, 0);

    // Then borrow some tokens
    contracts.poolProxy.borrow(tokenList.wbtc, borrowAmount, 2, 0, user);

    // Deal WBTC to user for repayment
    deal(tokenList.wbtc, user, borrowAmount);

    // Get permit signature
    bytes32 digest = _getPermitDigest(tokenList.wbtc, borrowAmount, 0, 1);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    // Repay with Permit2
    router.repayWithPermit2(tokenList.wbtc, borrowAmount, 2, user, 1, 0, signature);

    vm.stopPrank();
  }

  function test_revert_repayWithPermit2_InvalidAmount() public {
    uint256 borrowAmount = 1e6; // 1 WBTC
    uint256 repayAmount = 10e6; // 10 WBTC (more than borrowed)
    deal(tokenList.wbtc, user, repayAmount);

    vm.startPrank(user);

    // First supply some collateral
    uint256 collateralAmount = 20e6; // 20 USDX
    deal(tokenList.usdx, user, collateralAmount);
    IERC20(tokenList.usdx).approve(address(contracts.poolProxy), type(uint256).max);
    contracts.poolProxy.supply(tokenList.usdx, collateralAmount, user, 0);

    // Then borrow some tokens
    IERC20(tokenList.wbtc).approve(address(contracts.poolProxy), type(uint256).max);
    contracts.poolProxy.borrow(tokenList.wbtc, borrowAmount, 2, 0, user);

    // Approve Permit2
    IERC20(tokenList.wbtc).approve(PERMIT2_ADDRESS, type(uint256).max);

    // Get permit signature
    bytes32 digest = _getPermitDigest(tokenList.wbtc, repayAmount, 0, 1);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(bytes('INVALID_AMOUNT'));
    router.repayWithPermit2(tokenList.wbtc, repayAmount, 2, user, 1, 0, signature);

    vm.stopPrank();
  }

  function test_revert_supplyWithPermit2_InvalidSignature() public {
    uint256 amount = 10e6; // 10 WBTC
    deal(tokenList.wbtc, user, amount);

    vm.startPrank(user);

    // Approve Permit2
    IERC20(tokenList.wbtc).approve(PERMIT2_ADDRESS, type(uint256).max);

    // Get permit signature with wrong private key
    bytes32 digest = _getPermitDigest(tokenList.wbtc, amount, 0, 1);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xDEADBEEF, digest); // Wrong private key
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert('INVALID_SIGNATURE');
    router.supplyWithPermit2(tokenList.wbtc, amount, user, 0, 1, 0, signature);

    vm.stopPrank();
  }

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

    // Get domain separator from the Permit2 contract
    bytes32 domainSeparator = permit2.DOMAIN_SEPARATOR();

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function _getPermitDigest(
    address token,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 permit2TypeHash = keccak256(
      'PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
    );

    bytes32 tokenPermissionsHash = keccak256(
      abi.encode(keccak256('TokenPermissions(address token,uint256 amount)'), token, amount)
    );

    bytes32 structHash = keccak256(
      abi.encode(permit2TypeHash, tokenPermissionsHash, address(router), nonce, deadline)
    );

    // Get domain separator from the Permit2 contract
    bytes32 domainSeparator = permit2.DOMAIN_SEPARATOR();

    return keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
  }
}
