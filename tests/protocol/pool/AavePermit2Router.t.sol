// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {console2} from 'forge-std/console2.sol';

import {IPool} from '../../../src/contracts/interfaces/IPool.sol';
import {IAToken} from '../../../src/contracts/interfaces/IAToken.sol';
import {ISignatureTransfer} from 'permit2/interfaces/ISignatureTransfer.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AavePermit2Router} from '../../../src/contracts/protocol/pool/AavePermit2Router.sol';
import {TestnetERC20} from '../../../src/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {TestnetProcedures} from '../../utils/TestnetProcedures.sol';
import {EIP712SigUtils} from '../../utils/EIP712SigUtils.sol';
import {PermitSignature} from '../../../lib/permit2/test/utils/PermitSignature.sol';
import {DeployPermit2} from '../../../lib/permit2/test/utils/DeployPermit2.sol';
import {ISequencerOracle} from '../../../src/contracts/interfaces/ISequencerOracle.sol';
import {SequencerOracle} from '../../../src/contracts/mocks/oracle/SequencerOracle.sol';
import {PriceOracleSentinel} from '../../../src/contracts/misc/PriceOracleSentinel.sol';
import {IPoolAddressesProvider} from '../../../src/contracts/interfaces/IPoolAddressesProvider.sol';

contract AavePermit2RouterTest is TestnetProcedures, PermitSignature, DeployPermit2 {
  AavePermit2Router internal router;
  ISignatureTransfer internal permit2;
  address internal aUSDX;
  address internal aWBTC;

  uint256 internal userPrivateKey;
  address internal user;

  PriceOracleSentinel internal priceOracleSentinel;
  SequencerOracle internal sequencerOracleMock;

  function setUp() public virtual {
    initL2TestEnvironment();
    setupMockPriceOracle();

    // Setup test user
    userPrivateKey = 0xf738bd2dfd50b39e3245ff30f3bfcebd827218f37a41a4745566f0250d7f46ef; // Use a proper private key for testing
    user = vm.addr(userPrivateKey);

    // Get aToken addresses from protocol data provider
    (address aTokenAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.usdx
    );
    aUSDX = aTokenAddress;
    (aTokenAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(tokenList.wbtc);
    aWBTC = aTokenAddress;

    // Deploy Permit2
    permit2 = ISignatureTransfer(address(deployPermit2()));

    // Use deployed router
    router = AavePermit2Router(contracts.permit2Router);

    vm.startPrank(carol);
    contracts.poolProxy.supply(tokenList.usdx, 100_000e6, carol, 0);
    vm.stopPrank();

    vm.startPrank(user);
    // Approve Permit2 to spend WBTC and USDX
    IERC20(tokenList.wbtc).approve(address(permit2), type(uint256).max);
    IERC20(tokenList.usdx).approve(address(permit2), type(uint256).max);
    vm.stopPrank();
  }

  function test_supplyWithPermit2() public {
    uint256 supplyAmount = 0.1e8;
    deal(tokenList.wbtc, user, supplyAmount);

    uint256 deadlineOneHour = block.timestamp + 1 hours;

    // Generate permit2 signature
    bytes memory signature = _getPermit2Signature(
      address(router),
      tokenList.wbtc,
      supplyAmount,
      0, // nonce
      deadlineOneHour
    );

    vm.startPrank(user);

    // Supply with Permit2
    router.supplyWithPermit2(
      tokenList.wbtc,
      supplyAmount,
      user,
      0, // referralCode
      deadlineOneHour, // deadline
      0, // nonce
      signature
    );

    vm.stopPrank();

    // Verify supply
    assertEq(IERC20(tokenList.wbtc).balanceOf(user), 0);
    assertEq(IAToken(aWBTC).scaledBalanceOf(user), supplyAmount);
  }

  function test_repayWithPermit2() public {
    // First supply WBTC as collateral
    uint256 supplyAmount = 1e8; // 1 WBTC (8 decimals)
    deal(tokenList.wbtc, user, supplyAmount);
    uint256 deadlineOneHour = block.timestamp + 1 hours;
    // Generate permit2 signature for supply
    bytes memory supplySignature = _getPermit2Signature(
      address(router),
      tokenList.wbtc,
      supplyAmount,
      0, // nonce
      deadlineOneHour
    );
    vm.startPrank(user);
    // Supply WBTC with Permit2
    router.supplyWithPermit2(
      tokenList.wbtc,
      supplyAmount,
      user,
      0, // referralCode
      deadlineOneHour,
      0, // nonce
      supplySignature
    );
    // Borrow USDX using the pool directly
    uint256 borrowAmount = 1000e6; // 1000 USDX
    contracts.poolProxy.borrow(tokenList.usdx, borrowAmount, 2, 0, user);
    vm.stopPrank();
    // Now repay the USDX using permit2
    deal(tokenList.usdx, user, borrowAmount);
    // Generate permit2 signature for repay
    bytes memory repaySignature = _getPermit2Signature(
      address(router),
      tokenList.usdx,
      borrowAmount,
      1, // nonce (incremented from supply)
      deadlineOneHour
    );
    vm.startPrank(user);
    // Repay with Permit2
    router.repayWithPermit2(
      tokenList.usdx,
      borrowAmount,
      2, // variable rate mode
      user,
      deadlineOneHour,
      1, // nonce
      repaySignature
    );
    vm.stopPrank();
    // Verify repayment
    (, , , , uint256 variableDebt, , , , ) = contracts.protocolDataProvider.getUserReserveData(
      tokenList.usdx,
      user
    );
    assertEq(variableDebt, 0);
  }

  function _getPermit2Signature(
    address to,
    address token,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes memory) {
    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: token, amount: amount}),
      nonce: nonce,
      deadline: deadline
    });

    bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
    bytes32 msgHash = keccak256(
      abi.encodePacked(
        '\x19\x01',
        permit2.DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            _PERMIT_TRANSFER_FROM_TYPEHASH,
            tokenPermissions,
            to, // Use the router address directly
            permit.nonce,
            permit.deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, msgHash);
    return bytes.concat(r, s, bytes1(v));
  }
}
