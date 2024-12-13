// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IPermit2
 * @author Aave
 * @notice Interface for Uniswap's Permit2 contract
 * @dev This is a simplified interface only containing the methods needed for the Pool contract
 */
interface IPermit2 {
  struct TokenPermissions {
    address token;
    uint256 amount;
  }

  struct PermitTransferFrom {
    TokenPermissions permitted;
    uint256 nonce;
    uint256 deadline;
  }

  struct SignatureTransferDetails {
    address to;
    uint256 requestedAmount;
  }

  error SignatureExpired(uint256 signatureDeadline);
  error InvalidNonce();

  /**
   * @notice Transfer tokens according to the provided permit transfer data and signature
   * @param permit The permit data signed for transferring tokens
   * @param transferDetails The spender's requested transfer details for the permitted token
   * @param owner The owner of the tokens to transfer
   * @param signature The signature to verify
   */
  function permitTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
  ) external;

  /**
   * @notice Transfer tokens according to the provided permit batch transfer data and signature
   * @param permit The permit data signed for transferring tokens
   * @param transferDetails The spender's requested transfer details for the permitted token
   * @param owner The owner of the tokens to transfer
   * @param witness The witness value indicated in the witness type string
   * @param witnessTypeString The witness type string including the witness type hash
   * @param signature The signature to verify
   */
  function permitWitnessTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
  ) external;
}
