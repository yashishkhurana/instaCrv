// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Errors} from "./utils/Errors.sol";

contract LpToken is ERC20 {
  address public immutable minter;

  function _checkOnlyMinter() internal view {
    if (msg.sender != minter) revert Errors.UnAuthorized(msg.sender, minter);
  }

  constructor(address _minter, uint8 _decimals, string memory name, string memory symbol)
    ERC20(name, symbol, _decimals)
  {
    minter = _minter;
  }

  function mint(address _account, uint256 _amount) external returns (uint256) {
    _checkOnlyMinter();
    _mint(_account, _amount);
    return _amount;
  }
}
