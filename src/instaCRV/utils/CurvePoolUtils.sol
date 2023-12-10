// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

library CurvePoolUtils {
  uint256 internal constant _DEFAULT_IMBALANCE_THRESHOLD = 0.02e18;

  enum AssetType {
    USD,
    ETH,
    BTC,
    OTHER,
    CRYPTO
  }

  struct PoolMetaData {
    address pool;
    uint256 numberOfCoins;
    AssetType assetType;
    uint256[] decimals;
    uint256[] prices;
    uint256[] threshold;
  }

  //   function _ensurePoolIsBalanced(PoolMetaData memory poolMetaData) internal view {
  //     uint256 fromDecimals = poolMetaData.decimals[0];
  //     uint256 fromBalance = 10**fromDecimals;
  //     uint256 fromPrice = poolMetaData.prices[0];
  //     for(uint256 i = 1; i < poolMetaData.numberOfCoins; ++i) {
  //         uint256 toDecimals = poolMetaData.decimals[i];
  //         uint56
  //     }
  //   }
}
