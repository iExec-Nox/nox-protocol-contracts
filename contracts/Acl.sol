// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./interfaces/IACL.sol";

/**
 * @title ACL
 * @notice The ACL (Access Control List) is a permission management system designed to control access rights
 * for encrypted handles within the Nox protocol. By defining administrators and delegated viewers for each handle,
 * the ACL ensures that sensitive data remains protected while enabling authorized parties to interact with
 * encrypted resources in a secure and controlled manner.
 */
contract ACL is IACL {
    /// @notice Main storage structure following ERC-7201 pattern
    /// @dev Admins can manipulate a handle as input in computations, and can add other admins and viewers
    /// @dev Viewers can decrypt the associated data
    struct ACLStorage {
        mapping(bytes32 => mapping(address => bool)) admins;
        mapping(bytes32 => mapping(address => bool)) viewers;
        //TODO: Add Delegated Viewers
        //TODO: Add TEEComputeManager Contract Address
    }

    // keccak256(abi.encode(uint256(keccak256("nox.storage.ACL")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ACL_STORAGE_LOCATION =
        0xed401488ebb59e3713b284243aa87272e78f75cf6500206003b8bf39f01abd00;

    // ============ ALLOWANCE MANAGEMENT ============

    /**
     * @notice Grant admin role to another address for a specific handle
     * @dev Caller must have access (transient OR persistent) to the handle
     * @param handle The handle identifier
     * @param account The address to grant admin role
     */
    function allow(bytes32 handle, address account) external override {
        if (!isAllowed(handle, msg.sender)) revert SenderNotAllowed(msg.sender);
        if (account == address(0)) revert ZeroAddress();
        ACLStorage storage $ = _getACLStorage();
        $.admins[handle][account] = true;
        emit Allowed(msg.sender, account, handle);
    }

    /**
     * @notice Allows the use of `handle` by address `account` for this transaction.
     * @param handle Handle.
     * @param account Address of the account.
     */
    function allowTransient(bytes32 handle, address account) external override {
        // TODO: Implement transient permissions granting
    }
    
    // ============ ALLOWANCE QUERIES ============
    
    /**
     * @notice Returns whether the account is allowed to use the `handle`, either due to
     * allowTransient() or allow().
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (persistent or transient).
     */
    function isAllowed(bytes32 handle, address account) public view override returns (bool) {
        return isPersistentlyAllowed(handle, account) || isTransientlyAllowed(handle, account);
    }

    /**
     * @notice Returns `true` if the address is allowed to use an handle and `false` otherwise.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (persistent only).
     */
    function isPersistentlyAllowed(bytes32 handle, address account) internal view returns (bool) {
        ACLStorage storage $ = _getACLStorage();
        return $.admins[handle][account];
    }


    /**
     * @notice Checks whether the account is allowed to use the handle in the
     * same transaction (transient).
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access transiently the handle.
     */
    function isTransientlyAllowed(bytes32 handle, address account) internal pure returns (bool) {
        //TODO: Implement transient permissions check
        return false;
    }

    // ============ INTERNAL HELPERS ============
    
    /**
     * @notice Get the storage location for ACL data
     * @return $ The storage pointer
     */
    function _getACLStorage() private pure returns (ACLStorage storage $) {
        assembly {
            $.slot := ACL_STORAGE_LOCATION
        }
    }

}
