// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdStorage} from "forge-std/StdStorage.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {RbSimple} from "src/ReserveBucket/RbSimple.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import "forge-std/console.sol";

contract RbSimpleTest is Test {
  RbSimple rbSimple;
  WETH weth;

  event VaultInfo(address indexed _vaultAddress, address indexed _vaultOwner, uint256 _balance);

  // address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  address depositor = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address rewarder = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

  function setUp() public {
    weth = new WETH();
    rbSimple = new RbSimple(ERC20(address(weth)));
    emit VaultInfo(
      address(rbSimple), rbSimple.owner(), ERC20(address(weth)).balanceOf(address(rbSimple))
    );

    console.log("depositor - ", depositor);
    console.log("WETH - ", address(weth));
    console.log("Reserve Bucket Vault - ", address(rbSimple));
  }

  function _getWeth(uint256 _amount, address _user) internal {
    console.log(_user, " is asking for WETH");
    SafeTransferLib.safeTransferETH(address(weth), _amount);
    assertEq(ERC20(address(weth)).balanceOf(_user), 100 ether);
  }

  function testDeposit() public {
    vm.startPrank(depositor);

    address vault = address(rbSimple);
    ERC20(address(weth)).approve(vault, 100 ether);

    _getWeth(100 ether, depositor);

    console.log(
      "WETH balance of depositor after _getWeth -", ERC20(address(weth)).balanceOf(depositor)
    );

    rbSimple.deposit(100 ether, depositor);

    console.log(
      "vault share of depositor after deposit -",
      ERC20(address(rbSimple)).balanceOf(address(depositor)) / 1e18,
      "WETH"
    );
    vm.stopPrank();

    vm.startPrank(rewarder);
    _addRewards(100 ether);
    vm.stopPrank();
  }

  function _addRewards(uint256 _rewards) internal {
    _getWeth(_rewards, rewarder);
    uint256 oldBalanceOfVault = ERC20(address(weth)).balanceOf(address(rbSimple));
    ERC20(address(weth)).transfer(address(rbSimple), _rewards);
    assertEq(ERC20(address(weth)).balanceOf(address(rbSimple)), oldBalanceOfVault + _rewards);
  }
}
