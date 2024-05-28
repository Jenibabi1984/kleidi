// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @dev timestamp indicating that an operation is done
uint256 constant _DONE_TIMESTAMP = uint256(1);

/// @dev minimum delay for timelocked operations
uint256 constant MIN_DELAY = 2 days;

/// @dev maximum delay for timelocked operations
uint256 constant MAX_DELAY = 30 days;
