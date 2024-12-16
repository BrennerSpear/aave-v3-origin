// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {ISignatureTransfer} from 'permit2/interfaces/ISignatureTransfer.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title AavePermit2Router
 * @author Aave
 * @notice Router contract to handle Permit2 operations for the Aave Pool
 */
contract AavePermit2Router {
  using SafeERC20 for IERC20;

  ISignatureTransfer public immutable PERMIT2;
  IPool public immutable POOL;

  /**
   * @dev Constructor
   * @param permit2 The Permit2 contract address
   * @param pool The Aave Pool contract address
   */
  constructor(ISignatureTransfer permit2, IPool pool) {
    PERMIT2 = permit2;
    POOL = pool;
  }

  /**
   * @notice Supply assets with Permit2
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to supply
   * @param onBehalfOf The address that will receive the aTokens
   * @param referralCode Code used to register the integrator originating the operation
   * @param deadline The deadline timestamp that the permit is valid to
   * @param nonce The nonce used in the permit
   * @param signature The permit signature
   */
  function supplyWithPermit2(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint256 nonce,
    bytes calldata signature
  ) external {
    // First transfer the tokens to this contract using Permit2
    PERMIT2.permitTransferFrom(
      ISignatureTransfer.PermitTransferFrom({
        permitted: ISignatureTransfer.TokenPermissions({token: asset, amount: amount}),
        nonce: nonce,
        deadline: deadline
      }),
      ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount}),
      msg.sender,
      signature
    );

    // Approve the Pool to spend the tokens
    IERC20(asset).forceApprove(address(POOL), amount);

    // Supply the tokens to the Pool
    POOL.supply(asset, amount, onBehalfOf, referralCode);
  }

  /**
   * @notice Repay assets with Permit2
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * @param interestRateMode The interest rate mode at which the user wants to repay
   * @param onBehalfOf Address of the user who will get his debt reduced/removed
   * @param deadline The deadline timestamp that the permit is valid to
   * @param nonce The nonce used in the permit
   * @param signature The permit signature
   */
  function repayWithPermit2(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint256 nonce,
    bytes calldata signature
  ) external returns (uint256) {
    // First transfer the tokens to this contract using Permit2
    PERMIT2.permitTransferFrom(
      ISignatureTransfer.PermitTransferFrom({
        permitted: ISignatureTransfer.TokenPermissions({token: asset, amount: amount}),
        nonce: nonce,
        deadline: deadline
      }),
      ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount}),
      msg.sender,
      signature
    );

    // Approve the Pool to spend the tokens
    IERC20(asset).forceApprove(address(POOL), amount);

    // Repay the tokens to the Pool
    return POOL.repay(asset, amount, interestRateMode, onBehalfOf);
  }
}
