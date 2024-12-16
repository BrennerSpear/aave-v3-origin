// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISignatureTransfer} from '../../lib/permit2/src/interfaces/ISignatureTransfer.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockPermit2 is ISignatureTransfer {
  bytes32 private immutable _DOMAIN_SEPARATOR;
  mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

  constructor() {
    _DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('Permit2'),
        keccak256('1'),
        block.chainid,
        address(this)
      )
    );
  }

  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _DOMAIN_SEPARATOR;
  }

  function permitTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
  ) external {
    // Verify signature
    bytes32 tokenPermissionsHash = keccak256(
      abi.encode(
        keccak256('TokenPermissions(address token,uint256 amount)'),
        permit.permitted.token,
        permit.permitted.amount
      )
    );

    bytes32 permitHash = keccak256(
      abi.encode(
        keccak256(
          'PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
        ),
        tokenPermissionsHash,
        msg.sender,
        permit.nonce,
        permit.deadline
      )
    );

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', _DOMAIN_SEPARATOR, permitHash));

    // Verify signature
    require(_verifySignature(digest, signature, owner), 'INVALID_SIGNATURE');

    // Check deadline
    require(block.timestamp <= permit.deadline, 'PERMIT_DEADLINE_EXPIRED');

    // Check nonce
    require(
      (nonceBitmap[owner][permit.nonce >> 8] & (1 << (permit.nonce & 255))) == 0,
      'INVALID_NONCE'
    );
    nonceBitmap[owner][permit.nonce >> 8] |= 1 << (permit.nonce & 255);

    // Check amount
    require(transferDetails.requestedAmount <= permit.permitted.amount, 'INVALID_AMOUNT');

    // Transfer tokens
    require(
      IERC20(permit.permitted.token).transferFrom(
        owner,
        transferDetails.to,
        transferDetails.requestedAmount
      ),
      'TRANSFER_FROM_FAILED'
    );
  }

  function permitTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes calldata signature
  ) external {
    revert('NOT_IMPLEMENTED');
  }

  function permitWitnessTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
  ) external {
    revert('NOT_IMPLEMENTED');
  }

  function permitWitnessTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
  ) external {
    revert('NOT_IMPLEMENTED');
  }

  function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external {
    nonceBitmap[msg.sender][wordPos] |= mask;
  }

  function _verifySignature(
    bytes32 digest,
    bytes memory signature,
    address expectedSigner
  ) internal pure returns (bool) {
    require(signature.length == 65, 'INVALID_SIGNATURE_LENGTH');

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      r := mload(add(signature, 0x20))
      s := mload(add(signature, 0x40))
      v := byte(0, mload(add(signature, 0x60)))
    }

    return ecrecover(digest, v, r, s) == expectedSigner;
  }
}
