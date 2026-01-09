// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/**
 * @title IACL
 * @dev Interface for the ACL (Access Control List) permission management system
 */
interface IACL {
    /// Error thrown when sender doesn't have access to the handle
    error UnauthorizedSender(address sender);
    
    /// Error thrown when account address is zero
    error InvalidZeroAddress();

    /// Emitted when admin role is granted
    event Allowed(address indexed sender, address indexed account, bytes32 indexed handle);

    /**
     * Grant admin role to another address for a specific handle
     * @dev Caller must have access (transient OR persistent) to the handle
     * @param handle The handle identifier
     * @param account The address to grant admin role
     */
    function allow(bytes32 handle, address account) external;

    /**
     * Allows the use of `handle` by address `account` for this transaction.
     * @param handle Handle.
     * @param account Address of the account.
     */
    function allowTransient(bytes32 handle, address account) external;

    /**
     * Returns whether the account is allowed to use the `handle`, either due to
     * allowTransient() or allow().
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (persistent or transient).
     */
    function isAllowed(bytes32 handle, address account) external view returns (bool);
}
