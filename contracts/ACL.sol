// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IACL.sol";

/**
 * @title ACL
 * @dev The ACL (Access Control List) is a permission management system designed to control access rights
 * for encrypted handles within the Nox protocol. By defining administrators and delegated viewers for each handle,
 * the ACL ensures that sensitive data remains protected while enabling authorized parties to interact with
 * encrypted resources in a secure and controlled manner.
 */
contract ACL is IACL {
    /// Main storage structure following ERC-7201 pattern
    struct ACLStorage {
        /// Admins can use a handle as input in computations, and can add other admins and viewers
        mapping(bytes32 handleId => mapping(address => bool)) admins;
        /// Viewers can decrypt the associated data
        //TODO: Make viewer expirable
        mapping(bytes32 handleId => mapping(address => bool)) viewers;
        /// Handles that are publicly decryptable
        mapping(bytes32 handle => bool) isPubliclyDecryptable;
        //TODO: Add Delegated Viewers
        address teeComputeManager;
    }

    // keccak256(abi.encode(uint256(keccak256("nox.storage.ACL")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ACL_STORAGE_LOCATION =
        0xed401488ebb59e3713b284243aa87272e78f75cf6500206003b8bf39f01abd00;

    // ============ MODIFIERS ============
    /**
     * Ensures the account address is not zero
     * @param account The address to validate
     */
    modifier notZeroAddress(address account) {
        if (account == address(0)) {
            revert InvalidZeroAddress();
        }
        _;
    }

    /**
     * Ensures the sender is allowed to access the handle
     * @param handle The handle to check access for
     */
    modifier onlyAllowed(bytes32 handle) {
        if (!isAllowed(handle, msg.sender)) {
            revert UnauthorizedSender(msg.sender);
        }
        _;
    }

    // ============ CONSTRUCTOR ============
    constructor(address teeComputeManager) notZeroAddress(teeComputeManager) {
        ACLStorage storage $ = _getACLStorage();
        $.teeComputeManager = teeComputeManager;
    }
    
    // ============ PUBLIC DECRYPTION ============
    /// @inheritdoc IACL
    function allowPublicDecryption(bytes32 handle) external override {
        if (!isAllowed(handle, msg.sender)) {
            revert UnauthorizedSender(msg.sender);
        }
        
        ACLStorage storage $ = _getACLStorage();
        $.isPubliclyDecryptable[handle] = true;
        emit MarkedPubliclyDecryptable(msg.sender, handle);
    }

    /// @inheritdoc IACL
    function isPubliclyDecryptable(bytes32 handle) external view override returns (bool) {
        ACLStorage storage $ = _getACLStorage();
        return $.isPubliclyDecryptable[handle];
    }

    // ============ ALLOWANCE MANAGEMENT ============
    /// @inheritdoc IACL
    function allow(
        bytes32 handle,
        address account
    ) external override onlyAllowed(handle) notZeroAddress(account) {
        ACLStorage storage $ = _getACLStorage();
        $.admins[handle][account] = true;
        emit Allowed(msg.sender, account, handle);
    }

    /// @inheritdoc IACL
    function addViewer(
        bytes32 handle,
        address viewer
    ) external override onlyAllowed(handle) notZeroAddress(viewer) {
        ACLStorage storage $ = _getACLStorage();
        $.viewers[handle][viewer] = true;
        emit ViewerAdded(msg.sender, viewer, handle);
    }

    /**
     * @inheritdoc IACL
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
     */
    function allowTransient(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) {
        ACLStorage storage $ = _getACLStorage();
        if (msg.sender != $.teeComputeManager) {
            if (!isAllowed(handle, msg.sender)) {
                revert UnauthorizedSender(msg.sender);
            }
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

    /// @inheritdoc IACL
    function cleanTransientStorage() external override {
        assembly {
            let length := tload(0)
            tstore(0, 0)
            let lengthPlusOne := add(length, 1)
            for {
                let i := 1
            } lt(i, lengthPlusOne) {
                i := add(i, 1)
            } {
                let handle := tload(i)
                tstore(i, 0)
                tstore(handle, 0)
            }
        }
    }

    // ============ ALLOWANCE QUERIES ============
    /// @inheritdoc IACL
    function isViewer(bytes32 handle, address viewer) external view override returns (bool) {
        ACLStorage storage $ = _getACLStorage();
        return $.viewers[handle][viewer];
    }

    /// @inheritdoc IACL
    function isAllowed(bytes32 handle, address account) public view override returns (bool) {
        return isAllowedPersistent(handle, account) || isAllowedTransient(handle, account);
    }

    /**
     * Check if an address has persistent access to handle.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Returns `true` if the address has persistent access to a handle and `false` otherwise.
     */
    function isAllowedTransient(bytes32 handle, address account) internal view returns (bool) {
        bool isAllowedTransient_;
        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            isAllowedTransient_ := tload(key)
        }
        return isAllowedTransient_;
    }

    /**
     * Returns `true` if the address is allowed to use the handle and `false` otherwise.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (persistent only).
     */
    function isAllowedPersistent(bytes32 handle, address account) internal view returns (bool) {
        ACLStorage storage $ = _getACLStorage();
        return $.admins[handle][account];
    }

    // ============ INTERNAL HELPERS ============
    /**
     * Get the storage location for ACL data
     * @return $ The storage pointer
     */
    function _getACLStorage() private pure returns (ACLStorage storage $) {
        assembly {
            $.slot := ACL_STORAGE_LOCATION
        }
    }
}
