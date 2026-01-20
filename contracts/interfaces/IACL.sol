// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./IErrors.sol";

/**
 * @title IACL
 * @dev Interface for the ACL (Access Control List) permission management system
 */
interface IACL is IErrors {
    /// Error thrown when sender doesn't have access to the handle
    error UnauthorizedSender(address sender);

    /// Emitted when admin role is granted
    event Allowed(address indexed sender, address indexed account, bytes32 indexed handle);

    /// Emitted when viewer role is granted
    event ViewerAdded(address indexed sender, address indexed viewer, bytes32 indexed handle);

    /**
     * Grant admin role to another address for a specific handle
     * @dev Caller must have access (transient OR persistent) to the handle
     * @param handle The handle identifier
     * @param account The address to grant admin role
     */
    function allow(bytes32 handle, address account) external;

    /**
     * Add a viewer for a specific handle
     * @dev Only an admin can add a viewer. The viewer address cannot be address(0).
     * @param handle The handle identifier
     * @param viewer The address to grant viewer role
     */
    function addViewer(bytes32 handle, address viewer) external;

    /**
     * Allows the use of `handle` by address `account` for this transaction.
     * @param handle Handle.
     * @param account Address of the account.
     */
    function allowTransient(bytes32 handle, address account) external;

    /**
     * Removes all transient allowances. This is useful for integration with Account Abstraction
     * when bundling several UserOps calling the TEEComputeManager.
     * @dev Can be called by anyone (typically by AA bundlers between UserOps).
     */
    function cleanTransientStorage() external;

    /**
     * Returns whether the account is allowed to use the `handle`, either due to
     * allowTransient() or allow().
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (persistent or transient).
     */
    function isAllowed(bytes32 handle, address account) external view returns (bool);

    /**
     * Returns whether the account is a viewer for the handle.
     * @param handle Handle.
     * @param viewer Address of the viewer.
     * @return Whether the account is a viewer for the handle.
     */
    function isViewer(bytes32 handle, address viewer) external view returns (bool);
}
