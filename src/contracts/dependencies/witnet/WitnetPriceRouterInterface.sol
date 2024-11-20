// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum WitnetResponseStatus {
  Void,
  Awaiting,
  Ready,
  Error,
  Finalizing,
  Delivered
}

struct WitnetPrice {
  uint256 value;
  uint256 timestamp;
  bytes32 tallyHash;
  WitnetResponseStatus status;
}

interface WitnetProxyInterface {
  function latestPrice(bytes4 feedId) external view returns (WitnetPrice memory);

  function latestPrices(bytes4[] calldata feedIds) external view returns (WitnetPrice[] memory);
}
