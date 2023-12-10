// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

library Errors {
  error UnAuthorized(address caller, address authorizedCaller);
}
