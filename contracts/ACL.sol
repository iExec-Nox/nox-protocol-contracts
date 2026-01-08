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
    /// @dev Admins can use a handle as input in computations, and can add other admins and viewers
    /// @dev Viewers can decrypt the associated data
    struct ACLStorage {
        mapping(bytes32 handleId => mapping(address => bool)) admins;
        mapping(bytes32 handleId => mapping(address => bool)) viewers;
        //TODO: Add Delegated Viewers
        address TEEComputeManager;
    }

    // keccak256(abi.encode(uint256(keccak256("nox.storage.ACL")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ACL_STORAGE_LOCATION =
        0xed401488ebb59e3713b284243aa87272e78f75cf6500206003b8bf39f01abd00;
    
    constructor(address teeComputeManager) {
        ACLStorage storage $ = _getACLStorage();
        $.TEEComputeManager = teeComputeManager;
    }

    // ============ MODIFIERS ============

    /**
     * @notice Ensures the account address is not zero
     * @param account The address to validate
     */
    modifier notZeroAddress(address account) {
        if (account == address(0)) revert ZeroAddress();
        _;
    }

    // ============ ALLOWANCE MANAGEMENT ============

    /**
     * @notice Grant admin role to another address for a specific handle
     * @dev Caller must have access (transient OR persistent) to the handle
     * @param handle The handle identifier
     * @param account The address to grant admin role
     */
    function allow(bytes32 handle, address account) external override notZeroAddress(account) {
        if (!isAllowed(handle, msg.sender)) revert SenderNotAllowed(msg.sender);
        ACLStorage storage $ = _getACLStorage();
        $.admins[handle][account] = true;
        emit Allowed(msg.sender, account, handle);
    }

    /**
     * @notice Allows the use of `handle` by address `account` for this transaction.
     * @dev To grant transient access, the caller must already have permission on `handle`.
     *      The TEEComputeManager is exempt from this requirement and can always grant 
     *      transient permissions — a privilege not available with persistent `allow()`.
     *
     *      The TEEComputeManager uses this function in two scenarios:
     *      - For handles generated off-chain by the Handle Gateway, once the proof has been verified
     *      - For handles resulting from on-chain operations, where the caller naturally 
     *        inherits rights on the output handle
     *
     *      Transient access only lasts for the current transaction. It is the responsibility 
     *      of the application contract to convert this into persistent access via `allow()` 
     *      if needed.
     * @param handle Handle.
     * @param account Address of the account.
     */
    function allowTransient(bytes32 handle, address account) public override notZeroAddress(account) {
        ACLStorage storage $ = _getACLStorage();
        if (msg.sender != $.TEEComputeManager) {
            if (!isAllowed(handle, msg.sender)) revert SenderNotAllowed(msg.sender);
        }

        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            tstore(key, 1)
            let length := tload(0)
            let lengthPlusOne := add(length, 1)
            tstore(lengthPlusOne, key)
            tstore(0, lengthPlusOne)
        }
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
     * @notice Returns `true` if the address is allowed to use an handle transiently and `false` otherwise.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (transient only).
     */
    function isTransientlyAllowed(bytes32 handle, address account) internal view returns (bool) {
        bool isAllowedTransient;
        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            isAllowedTransient := tload(key)
        }
        return isAllowedTransient;  
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
