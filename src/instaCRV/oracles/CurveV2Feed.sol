// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Oracle} from "./Oracle.sol";

contract CurveV2Feed is Oracle {
  address private asset0;
  address private asset1;

  constructor(address _poolAddress) {}

  function getPriceInEth(address _token) external view virtual override returns (uint256) {
    return 0;
  }

  function isTokenSupported(address _token) external view virtual override returns (bool) {
    return true;
  }
}
