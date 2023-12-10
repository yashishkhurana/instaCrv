// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import "forge-std/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {CurveRegistryCache} from "src/instaCrv/CurveRegistryCache.sol";
import {CurvePools} from "./curvePools.sol";

contract CurveRegistryCacheTest is Test {
  address internal constant _CURVE_REGISTRY_ADDRESS = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC;
  address internal constant _AAVE_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;
  CurveRegistryCache crc;

  function setUp() public {
    crc = new CurveRegistryCache();
  }

  // function testIsCurvePool() public {
  //   assertEq(
  //     crc.isCurvePool(0x54586bE62E3c3580375aE3723C145253060Ca0C2, _CURVE_REGISTRY_ADDRESS), false
  //   );
  // }

  // function testIsCurvePoolTrue() public {
  //   assertEq(crc.isCurvePool(CurvePools.FRAX_3CRV, _CURVE_REGISTRY_ADDRESS), true);
  // }
}
