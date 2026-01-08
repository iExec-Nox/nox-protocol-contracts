// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/**
 * @title IACL
 * @notice Interface for the ACL (Access Control List) contract
 */
interface IACL {
    /// @notice Structure containing permission mappings for a handle
    /// @dev Admins can manipulate a handle as input in computations, and can add other admins and viewers
    /// @dev Viewers can decrypt the associated data
    struct HandleInfo {
        mapping(address => bool) admins;
        mapping(address => bool) viewers;
        //TODO: Add Delegated Viewers
    }
}
