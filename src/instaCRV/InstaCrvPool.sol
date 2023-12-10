// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {LpToken} from "./LpToken.sol";
import {EnumerableSet} from "./utils/EnumerableSet.sol";
import {EnumerableMap} from "./utils/EnumerableMap.sol";
import {Controller} from "./Controller.sol";
import {CurveRegistryCache} from "./CurveRegistryCache.sol";
import {ArrayExtensions} from "./utils/ArrayExtensions.sol";
import {ScaledMath} from "./utils/ScaledMath.sol";

contract InstaCrv is Owned {
  using ScaledMath for uint256;
  using ArrayExtensions for uint256[];
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableMap for EnumerableMap.AddressToUintMap;

  struct DepositVariables {
    uint256 exchangeRate;
    uint256 underlyingBalanceIncrease;
    uint256 mintableUnderlyingAmount;
    uint256 lpReceived;
    uint256 underlyingBalanceBefore;
    uint256 allocatedBalanceBefore;
    uint256[] allocatedPerPoolBefore;
    uint256 underlyingBalanceAfter;
    uint256 allocatedBalanceAfter;
    uint256[] allocatedPerPoolAfter;
  }

  uint256 internal constant _IDLE_RATIO_UPPER_BOUND = 0.2e18;
  uint256 internal constant _MIN_DEPEG_THRESHOLD = 0.01e18;
  uint256 internal constant _MAX_DEPEG_THRESHOLD = 0.1e18;
  uint256 internal constant _MAX_DEVIATION_UPPER_BOUND = 0.2e18;
  uint256 internal constant _DEPEG_UNDERLYING_MULTIPLIER = 2;
  uint256 internal constant _TOTAL_UNDERLYING_CACHE_EXPIRY = 3 days;
  uint256 internal constant _MAX_ETH_LP_VALUE_FOR_REMOVING_CURVE_POOL = 100e18;

  ERC20 public immutable underlying;
  LpToken public immutable lpToken;
  Controller public immutable controller;

  uint256 public maxDeviation = 0.02e18; // 2%
  uint256 public maxIdleCurveLpRatio = 0.05e18;
  bool public isShutDown;
  uint256 public depegThreshold = 0.03e18; // 3%
  uint256 internal _cacheUpdatedTimestamp;
  uint256 internal _cachedTotalUnderlying;

  EnumerableSet.AddressSet internal _curvePools;
  EnumerableMap.AddressToUintMap internal weights;

  bool public rebalancingFeeActive;

  ERC20 public immutable CRV;
  ERC20 public immutable CVX;
  address internal constant _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  // hardcode some pools to storage

  // frxETH/WETH
  address constant lp0Token = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc;
  address constant lp0Pool = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc;

  // rETH/frxETH
  address constant lp1Token = 0xbA6c373992AD8ec1f7520E5878E5540Eb36DeBf1;
  address constant lp1Pool = 0xe7c6E0A739021CdbA7aAC21b4B728779EeF974D9;

  // cbETH/ETH
  address constant lp2Token = 0x5b6C539b224014A09B3388e51CaAA8e354c959C8;
  address constant lp2Pool = 0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A;

  error TooMuchSlippage();

  constructor(
    address _controller,
    address _underlying,
    string memory _lpTokenName,
    string memory _symbol,
    address _cvx,
    address _crv
  ) Owned(_controller) {
    underlying = ERC20(_underlying);
    uint8 decimals = ERC20(_underlying).decimals();
    lpToken = new LpToken(address(this), decimals, _lpTokenName, _symbol);
    CRV = ERC20(_crv);
    CVX = ERC20(_cvx);
    controller = Controller(_controller);
  }

  error FailedToAddPool();

  function initSavedPools() external onlyOwner {
    weights.set(lp0Pool, 0);
    weights.set(lp1Pool, 0);
    weights.set(lp2Pool, 0);

    if (!_curvePools.add(lp0Pool) && !_curvePools.add(lp1Pool) && !_curvePools.add(lp2Pool)) {
      revert FailedToAddPool();
    }
  }

  error NotWethPool();
  error PoolIsShutdown();
  error UnderlyingAmountCannotBeZero();

  receive() external payable {
    if (address(underlying) == _WETH_ADDRESS) revert NotWethPool();
  }

  event Deposit(
    address indexed sender, address indexed receiver, uint256 depositedAmount, uint256 lpReceived
  );

  function depositFor(address _account, uint256 _underlyingAmount, uint256 _minLpReceived)
    public
    returns (uint256)
  {
    DepositVariables memory vars;

    if (!isShutDown) revert PoolIsShutdown();
    if (_underlyingAmount <= 0) revert UnderlyingAmountCannotBeZero();

    // deposit WETH into this address
    // this address caches this deposit
    // this address deposits the WETH into the least allocated curve pool

    // get balances
    (vars.underlyingBalanceBefore, vars.allocatedBalanceBefore, vars.allocatedPerPoolBefore) =
      _getTotalAndPerPoolUnderlying();

    // get exchange rate for this vault share
    vars.exchangeRate = _exchangeRate(vars.underlyingBalanceBefore);

    // transfer WETH to this address
    underlying.transferFrom(msg.sender, address(this), _underlyingAmount);

    // deposit to curve
    _depositToCurve(
      vars.allocatedBalanceBefore, vars.allocatedPerPoolBefore, underlying.balanceOf(address(this))
    );

    // get balances to update
    (vars.underlyingBalanceAfter, vars.allocatedBalanceAfter, vars.allocatedPerPoolAfter) =
      _getTotalAndPerPoolUnderlying();

    vars.underlyingBalanceIncrease = vars.underlyingBalanceAfter - vars.underlyingBalanceBefore;

    vars.mintableUnderlyingAmount =
      FixedPointMathLib.min(_underlyingAmount, vars.underlyingBalanceIncrease);

    vars.lpReceived = vars.mintableUnderlyingAmount.divDown(vars.exchangeRate);

    if (vars.lpReceived < _minLpReceived) revert TooMuchSlippage();

    lpToken.mint(_account, vars.lpReceived);

    _cachedTotalUnderlying = vars.underlyingBalanceAfter;
    _cacheUpdatedTimestamp = block.timestamp;

    emit Deposit(msg.sender, _account, _underlyingAmount, vars.lpReceived);

    return vars.lpReceived;
  }

  function _exchangeRate() public returns (uint256) {
    return _exchangeRate(totalUnderlying());
  }

  function _exchangeRate(uint256 _totalUnderlying) internal view returns (uint256) {
    uint256 lpSupply = lpToken.totalSupply();

    if (lpSupply == 0 || _totalUnderlying == 0) return ScaledMath.ONE;

    return _totalUnderlying.divDown(lpSupply);
  }

  function totalUnderlying() public returns (uint256) {
    (uint256 _totalUnderlying,,) = _getTotalAndPerPoolUnderlying();

    return _totalUnderlying;
  }

  function _depositToCurve(
    uint256 _totalUnderlying,
    uint256[] memory _allocatedPerPool,
    uint256 _underlyingAmount
  ) internal {
    // amount just deposited
    uint256 _depositsRemaining = _underlyingAmount;

    uint256 _totalAfterDeposit = _totalUnderlying + _underlyingAmount;

    uint256[] memory allocatedPerPoolCache = _allocatedPerPool.copy();

    while (_depositsRemaining > 0) {
      (uint256 _curvePoolIndex, uint256 _maxDeposit) =
        _getDepositPool(_totalAfterDeposit, _allocatedPerPool);

      if (_depositsRemaining < _maxDeposit + 1e2) _maxDeposit = _depositsRemaining;

      address _curvePool = _curvePools.at(_curvePoolIndex);

      uint256 _toDeposit = FixedPointMathLib.min(_depositsRemaining, _maxDeposit);
      _depositToCurvePool(_curvePool, _toDeposit);
      _depositsRemaining -= _toDeposit;
      allocatedPerPoolCache[_curvePoolIndex] += _toDeposit;
    }
  }

  // TODO should zap into any LP token
  function _depositToCurvePool(address _curvePool, uint256 _underlyingAmount) internal {
    if (_underlyingAmount == 0) return;
    address _curveHandler = controller.curveHandler();
    bytes memory data = abi.encodeWithSignature(
      "deposit(address,address,uint256)", _curvePool, address(controller), _underlyingAmount
    );
    assembly {
      let success := delegatecall(gas(), _curveHandler, add(data, 32), mload(data), 0, 0)
      if iszero(success) { revert(0x00, 0x00) }
    }
  }

  function _getTotalAndPerPoolUnderlying()
    internal
    view
    returns (uint256 _totalUnderlying, uint256 _totalAllocated, uint256[] memory _perPoolUnderlying)
  {
    uint256 _curvePoolsLength = _curvePools.length();
    _perPoolUnderlying = new uint256[](_curvePoolsLength);

    for (uint256 i = 0; i < _curvePoolsLength; ++i) {
      address _curvePool = _curvePools.at(i);
      uint256 _poolUnderlying = _curveLpToUnderlying(
        controller.curveRegistryCache().lpToken(_curvePool), totalCurveLpBalance(_curvePool)
      );
      _perPoolUnderlying[i] = _poolUnderlying;
      _totalAllocated += _poolUnderlying;
    }

    _totalUnderlying = _totalAllocated + underlying.balanceOf(address(this));
  }

  function _getDepositPool(uint256 _totalUnderlying, uint256[] memory _allocatedPerPool)
    internal
    view
    returns (uint256 poolIndex, uint256 maxDepositAmount)
  {
    uint256 _curvePoolCount = _allocatedPerPool.length;
    int256 iPoolIndex = -1;
    for (uint256 i = 0; i < _curvePoolCount; i++) {
      address _curvePool = _curvePools.at(i);
      uint256 _allocatedUnderlying = _allocatedPerPool[i];
      uint256 _targetAllocation = _totalUnderlying.mulDown(weights.get(_curvePool));
      if (_allocatedUnderlying >= _targetAllocation) continue;
      uint256 _maxBalance = _targetAllocation + _targetAllocation.mulDown(_getMaxDeviation());
      uint256 _maxDepositAmount = _maxBalance - _allocatedUnderlying;
      if (_maxDepositAmount <= maxDepositAmount) continue;
      maxDepositAmount = _maxDepositAmount;
      iPoolIndex = int256(i);
    }
    require(iPoolIndex > -1, "error retrieving deposit pool");
    poolIndex = uint256(iPoolIndex);
  }

  function _curveLpToUnderlying(address _curveLpToken, uint256 _curveLpAmount)
    internal
    view
    returns (uint256)
  {
    // get price for 1 LP token
    // return price * total number of LP in balance
    return ScaledMath.ONE;
  }

  // controller and admin functions
  // function addCurvePool(address _pool) external onlyOwner {
  //   require(!_curvePools.contains(_pool));
  //   CurveRegistryCache _registry = controller.curveRegistryCache();
  //   // _registry.
  // }

  function totalCurveLpBalance(address _pool) public view returns (uint256) {
    //
    return 0;
  }

  function _stakedCurveLpBalance(address _pool) internal view returns (uint256) {
    //
    return 0;
  }

  function _idleCurveLpBalance(address _pool) internal view returns (uint256) {
    return ERC20(controller.curveRegistryCache().lpToken(_pool)).balanceOf(address(this));
  }

  function _getMaxDeviation() internal view returns (uint256) {
    return rebalancingFeeActive ? 0 : maxDeviation;
  }

  function allCurvePools() external view returns (address[] memory) {
    return _curvePools.values();
  }

  function curvePoolsCount() external view returns (uint256) {
    return _curvePools.length();
  }

  function getCurvePoolAtIndex(uint256 _index) external view returns (address) {
    return _curvePools.at(_index);
  }

  function isRegisteredCurvePool(address _pool) public view returns (bool) {
    return _curvePools.contains(_pool);
  }

  function getPoolWeight(address _pool) external view returns (uint256) {
    (, uint256 _weight) = weights.tryGet(_pool);
    return _weight;
  }
}
