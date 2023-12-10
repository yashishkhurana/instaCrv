// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract Oracle {
  function getPriceInEth(address _token) external view virtual returns (uint256);
  function isTokenSupported(address _token) external view virtual returns (bool);

  event TokenUpdated(address indexed _token, address _feed, uint256 _maxDelay, bool _isEthPrice);
}
