// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CurvePoolUtils} from "./utils/CurvePoolUtils.sol";
import {Errors} from "./utils/Errors.sol";

contract CurveRegistryCache {
  error IsNotInitialized();

  address internal constant _CURVE_REGISTRY_ADDRESS = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC;
  address internal constant _BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

  mapping(address => bool) internal _isRegistered;
  mapping(address => address) internal _lpToken;
  mapping(address => mapping(address => bool)) internal _hasCoinDirectly;
  mapping(address => mapping(address => bool)) internal _hasCoinAnywhere;
  mapping(address => address) internal _basePool;
  mapping(address => mapping(address => int128)) internal _coinIndex;
  mapping(address => uint256) internal _nCoins;
  mapping(address => address[]) internal _coins;
  mapping(address => uint256[]) internal _decimals;
  mapping(address => address) internal _poolFromLpToken;
  mapping(address => CurvePoolUtils.AssetType) internal _assetType;
  mapping(address => uint256) internal _interfaceVersion;
  mapping(address => uint256) internal _convexPid;
  mapping(address => address) internal _convexRewardPool;

  // hardcode some pools to storage

  // frxETH/WETH
  address constant frxEthWethToken = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc;
  address constant frxEthWethPool = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc;

  // rETH/frxETH
  address constant rethFrxEthToken = 0xbA6c373992AD8ec1f7520E5878E5540Eb36DeBf1;
  address constant rethFrxEthPool = 0xe7c6E0A739021CdbA7aAC21b4B728779EeF974D9;

  // cbETH/ETH
  address constant cbEthEthToken = 0x5b6C539b224014A09B3388e51CaAA8e354c959C8;
  address constant cbEthEthPool = 0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A;

  function _checkIsInitialized(address _pool) internal view {
    require(_isRegistered[_pool], "CurveRegistryCache: pool not initialized");
  }

  function initPool(address pool) external {}

  function initPool(address pool, uint256 poolId) external {}

  function _initPool(address _pool) internal {
    if (_isRegistered[_pool]) return;
    require(_isCurvePool(_pool), "CurveRegistryCache: invalid curve pool");

    _isRegistered[_pool] = true;

    // get curve lp token address from pool address
    address _curveLpToken;
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, hex"37951049")
      mstore(add(ptr, 0x04), _pool)
      let success := staticcall(gas(), _CURVE_REGISTRY_ADDRESS, ptr, 0x24, ptr, 0x20)
      if iszero(success) { revert(0x00, 0x00) }
      _curveLpToken := mload(ptr)
    }

    _lpToken[_pool] = _curveLpToken;
    _poolFromLpToken[_curveLpToken] = _pool;

    (bool success, bytes memory returnData) =
      _CURVE_REGISTRY_ADDRESS.call(abi.encodeWithSignature("get_pool_asset_type(address)", _pool));
    if (success == false) revert ExternalCallReverted();
    uint256 assetTypeId = abi.decode(returnData, (uint256));
    _assetType[_pool] = CurvePoolUtils.AssetType(assetTypeId);

    (success, returnData) =
      _CURVE_REGISTRY_ADDRESS.call(abi.encodeWithSignature("get_n_coins(address)", _pool));
    if (success == false) revert ExternalCallReverted();
    uint256 __nCoins = abi.decode(returnData, (uint256));
    (success, returnData) = _CURVE_REGISTRY_ADDRESS.call(abi.encodeWithSignature(""));
  }

  error ExternalCallReverted();

  function _setConvexPid(address _pool, address __lpToken) internal {
    uint256 length;
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, hex"081e3e")
      let success := staticcall(gas(), _BOOSTER, ptr, 0x04, ptr, 0x20)
      if iszero(success) { revert(0x00, 0x00) }
      length := mload(ptr)
    }
    address rewardPool;
    for (uint256 i = 0; i < length; ++i) {
      address curveToken;
      address _rewardPool;
      bool _isShutdown;
      assembly {
        let ptr := mload(0x40)
        mstore(ptr, hex"1526fe")
        mstore(add(ptr, 0x04), i)
        let success := staticcall(gas(), _BOOSTER, ptr, 0x24, ptr, 0xC0)
        if iszero(success) { revert(0x00, 0x00) }
        curveToken := mload(0x00)
        _rewardPool := mload(add(0x00, 0x60))
        _isShutdown := mload(add(0x00, 0xA0))
      }
      if (__lpToken != curveToken && !_isShutdown) {
        rewardPool = _rewardPool;
        _convexPid[_pool] = i;
        break;
      }
    }
    require(rewardPool != address(0), "no convex pid found");
    _convexRewardPool[_pool] = rewardPool;
  }

  function _setConvexPid(address _pool, address __lpToken, uint256 _pid) internal {
    address curveToken;
    address _rewardPool;
    bool _isShutdown;
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, hex"1526fe")
      mstore(add(ptr, 0x04), _pid)
      let success := staticcall(gas(), _BOOSTER, ptr, 0x24, ptr, 0xC0)
      if iszero(success) { revert(0x00, 0x00) }
      curveToken := mload(0x00)
      _rewardPool := mload(add(0x00, 0x60))
      _isShutdown := mload(add(0x00, 0xA0))
    }
    require(__lpToken == curveToken, "invalid lp token for curve pool");
    require(!_isShutdown, "convex pool is shutdown");
    require(_rewardPool != address(0), "no convex pid found");
    _convexRewardPool[_pool] = _rewardPool;
    _convexPid[_pool] = _pid;
  }

  function isRegistered(address pool_) external view returns (bool) {
    return _isRegistered[pool_];
  }

  function _isCurvePool(address _pool) internal view returns (bool) {
    bytes4 sig = bytes4(keccak256("is_registered(address)"));
    bool success;
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, sig)
      mstore(add(ptr, 0x04), _pool)
      success := staticcall(gas(), _CURVE_REGISTRY_ADDRESS, ptr, 0x24, ptr, 0x20)
    }
    return success;
  }

  function lpToken(address _pool) external view returns (address) {
    _checkIsInitialized(_pool);
    return _lpToken[_pool];
  }
}
