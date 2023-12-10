// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Oracle} from "./Oracle.sol";

contract CurveV2NgFeed is Oracle {
  address private asset0;
  address private asset1;

  constructor(address _poolAddress) {}

  function getPriceInEth(address _token) external view virtual override returns (uint256) {
    // asset0.getchainlinkprice()
    // asset1.getchainlinkprice()
    return 0;
  }

  function isTokenSupported(address _token) external view virtual override returns (bool) {
    // check registry
    // check from registry if the pool is supported
    return true;
  }
}
