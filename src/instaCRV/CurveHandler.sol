// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Controller} from "./Controller.sol";
import {CurveRegistryCache} from "./CurveRegistryCache.sol";

contract CurveHandler {
  ERC20 internal constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  Controller internal immutable controller;

  constructor(address _controller) {
    controller = Controller(_controller);
  }

  function deposit(address _curvePool, address _token, uint256 _amount) public {
    CurveRegistryCache _registry = controller.curveRegistryCache();
    // external call
  }

  function withdraw(address _curvePool, address _token, uint256 _amount) external {
    // external call
  }
}
