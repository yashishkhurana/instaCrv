// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {EnumerableSet} from "./utils/EnumerableSet.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {Oracle} from "./oracles/Oracle.sol";
import {CurveRegistryCache} from "./CurveRegistryCache.sol";

contract Controller is Owned {
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 internal constant _MAX_WEIGHT_UPDATE_MIN_DELAY = 32 days;
  uint256 internal constant _MIN_WEIGHT_UPDATE_MIN_DELAY = 1 days;

  EnumerableSet.AddressSet internal _pools;
  EnumerableSet.AddressSet internal _activePools;

  address public curveHandler;
  address public convexHandler;
  Oracle public priceOracle;
  CurveRegistryCache public curveRegistryCache;

  constructor() Owned(msg.sender) {}

  function setPriceOracle(address _oracle) external onlyOwner {
    priceOracle = Oracle(_oracle);
  }

  function setCurveHandler(address _curveHandler) external onlyOwner {
    curveHandler = _curveHandler;
  }

  function setConvexHandler(address _convexHandler) external onlyOwner {
    convexHandler = _convexHandler;
  }
}
