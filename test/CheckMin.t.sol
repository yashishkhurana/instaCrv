// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract CheckMinTest is Test {
  CheckMin min;
  uint256 a = 2;
  uint256 b = 3;

  function setUp() public {
    min = new CheckMin();
  }

  function testMinSolidity() public {
    assertEq((a < b ? a : b), 2);
  }

  function testMinYul() public {
    assertEq(min.checkMin(a, b), b);
  }
}

contract CheckMin {
  function checkMin(uint256 _a, uint256 _b) external pure returns (uint256) {
    assembly {
      let result := lt(_a, _b)
      result := add(mul(_a, iszero(result)), mul(_b, result))
      mstore(0x40, result)
      return(0x40, 0x20)
    }
  }
}
