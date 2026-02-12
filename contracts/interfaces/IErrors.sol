// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title IErrors
 * @notice Common error definitions shared across contracts
 */
interface IErrors {
    /// Error thrown when account address is zero
    error InvalidZeroAddress();

    /// Error thrown when bytes parameter is empty
    error InvalidEmptyBytes();
}
