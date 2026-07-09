// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";
import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";
import {HandleUtils} from "../utils/HandleUtils.sol";
import {TEEType, TypeUtils} from "../utils/TypeUtils.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";
import {Common} from "./Common.sol";

/**
 * @title ACL
 * @notice Access control for encrypted handles. Supports persistent and transient access,
 * plus viewer and public-decryption roles.
 */
abstract contract ACL is Common {
    using SlotDerivation for bytes32;
    using TransientSlot for bytes32;
    using TransientSlot for TransientSlot.BooleanSlot;

    bytes32 private constant ACL_TRANSIENT_STORAGE_BASE_SLOT = keccak256(
        "nox.storage.transient.ACL"
    );

    bytes32 private constant PUBLIC_HANDLE_TRANSIENT_BASE_SLOT = keccak256(
        "nox.storage.transient.PublicHandle"
    );

    modifier notZeroAddress(address account) {
        require(account != address(0), InvalidZeroAddress());
        _;
    }

    /**
     * Ensures the sender is allowed to access the handle
     * @param handle The handle to check access for
     */
    modifier onlyAllowed(bytes32 handle) {
        require(_isAllowed(handle, msg.sender), UnauthorizedSender(msg.sender));
        _;
    }

    /**
     * Prevents ACL mutations on public handles.
     * Applied before onlyAllowed to avoid unnecessary storage reads.
     * @param handle The handle to check
     */
    modifier notPublicHandle(bytes32 handle) {
        require(!HandleUtils.isPublicHandle(handle), PublicHandleACLForbidden());
        _;
    }

    /// @inheritdoc INoxCompute
    function isAllowed(bytes32 handle, address account) external view override returns (bool) {
        return _isAllowed(handle, account);
    }

    /// @inheritdoc INoxCompute
    function validateAllowedForAll(
        address account,
        bytes32[] calldata handles
    ) external view override {
        _validateAllowedForAll(account, handles);
    }

    /// @inheritdoc INoxCompute
    function allow(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) notPublicHandle(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.admins[handle][account] = true;
        emit Allowed(msg.sender, account, handle);
    }

    /**
     * @inheritdoc INoxCompute
     * @dev To grant transient access, the caller must already have permission on `handle`.
     *      Transient access only lasts for the current transaction. It is the responsibility
     *      of the application contract to convert this into persistent access via `allow()`
     *      if needed.
     */
    function allowTransient(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) notPublicHandle(handle) onlyAllowed(handle) {
        _allowTransient(handle, account);
    }

    /// @inheritdoc INoxCompute
    function disallowTransient(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) notPublicHandle(handle) onlyAllowed(handle) {
        ACL_TRANSIENT_STORAGE_BASE_SLOT
            .deriveMapping(handle)
            .deriveMapping(account)
            .asBoolean()
            .tstore(false);
    }

    /// @inheritdoc INoxCompute
    function addViewer(
        bytes32 handle,
        address viewer
    ) external override notZeroAddress(viewer) notPublicHandle(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.viewers[handle][viewer] = true;
        emit ViewerAdded(msg.sender, viewer, handle);
    }

    /// @inheritdoc INoxCompute
    function isViewer(bytes32 handle, address viewer) external view override returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return
            HandleUtils.isPublicHandle(handle) ||
            $.isPubliclyDecryptable[handle] ||
            $.viewers[handle][viewer] ||
            $.admins[handle][viewer];
    }

    /// @inheritdoc INoxCompute
    function allowPublicDecryption(
        bytes32 handle
    ) external override notPublicHandle(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.isPubliclyDecryptable[handle] = true;
        emit MarkedAsPubliclyDecryptable(msg.sender, handle);
    }

    /// @inheritdoc INoxCompute
    function isPubliclyDecryptable(bytes32 handle) external view override returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return HandleUtils.isPublicHandle(handle) || $.isPubliclyDecryptable[handle];
    }

    /**
     * Grants transient access to a handle for an account. This function does not do any
     * checks and should be used with caution.
     * This function is used in two scenarios:
     *   - For handles generated off-chain by the Handle Gateway, once the proof has been verified
     *   - For handles resulting from on-chain operations, where the caller naturally inherits
     *     rights on the output handle
     * @param handle Handle identifier
     * @param account Address of the account
     */
    function _allowTransient(bytes32 handle, address account) internal override {
        // Public handles don't need ACL; skip silently to save gas.
        if (HandleUtils.isPublicHandle(handle)) {
            return;
        }
        ACL_TRANSIENT_STORAGE_BASE_SLOT
            .deriveMapping(handle)
            .deriveMapping(account)
            .asBoolean()
            .tstore(true);
    }

    /**
     * Reverts if account lacks access to any handle in the array.
     */
    function _validateAllowedForAll(
        address account,
        bytes32[] memory handles
    ) internal view override {
        for (uint256 i = 0; i < handles.length; ++i) {
            if (!_isAllowed(handles[i], account)) {
                revert NotAllowed(handles[i], account);
            }
        }
    }

    /**
     * Checks if the account is allowed to access the handle.
     * For public handles, access is granted if any of the following conditions are met:
     *   - The handle was wrapped in the current transaction (transient registry)
     *   - The handle was previously persisted via persistTransientHandle (persistent registry)
     *   - The handle equals the canonical zero handle for its type
     * Checks are ordered cheapest-first: transient tload short-circuits before the SLOAD, and both
     * short-circuit before the _isZeroHandle loop.
     * For unique handles, the standard transient or persistent ACL applies.
     */
    function _isAllowed(bytes32 handle, address account) private view returns (bool) {
        if (HandleUtils.isPublicHandle(handle)) {
            NoxComputeStorage storage $ = _getNoxComputeStorage();
            return
                _isRegisteredTransientPublicHandle(handle) ||
                $.isRegisteredPublicHandle[handle] ||
                _isZeroHandle(handle);
        }
        return _isAllowedTransient(handle, account) || _isAllowedPersistent(handle, account);
    }

    /**
     * Registers a public handle in transient storage so it is accessible within the
     * current transaction without a persistent SSTORE.
     * @param handle The public handle to register transiently
     */
    function _registerTransientPublicHandle(bytes32 handle) internal override {
        PUBLIC_HANDLE_TRANSIENT_BASE_SLOT.deriveMapping(handle).asBoolean().tstore(true);
    }

    /**
     * Returns true if the public handle was registered transiently in the current transaction.
     * @param handle The public handle to check
     */
    function _isRegisteredTransientPublicHandle(
        bytes32 handle
    ) internal view override returns (bool) {
        return PUBLIC_HANDLE_TRANSIENT_BASE_SLOT.deriveMapping(handle).asBoolean().tload();
    }

    /**
     * Returns true if `handle` exactly equals the canonical zero handle for any of the
     * currently supported TEE types.
     * @param handle The handle to check
     */
    function _isZeroHandle(bytes32 handle) internal view returns (bool) {
        TEEType[] memory supportedTypes = TypeUtils.allCurrentlySupportedTypes();
        for (uint256 i = 0; i < supportedTypes.length; ++i) {
            if (handle == HandleUtils.zeroHandle(supportedTypes[i])) {
                return true;
            }
        }
        return false;
    }

    /// @inheritdoc INoxCompute
    function persistTransientHandle(bytes32 handle) external override {
        require(HandleUtils.isPublicHandle(handle), NotPublicHandle());
        require(_isRegisteredTransientPublicHandle(handle), UnregisteredPublicHandle(handle));
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.isRegisteredPublicHandle[handle] = true;
        emit PublicHandlePersisted(msg.sender, handle);
    }

    /**
     * Check if an address has transient access to handle.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Returns `true` if the address has transient access to a handle and `false` otherwise.
     */
    function _isAllowedTransient(bytes32 handle, address account) private view returns (bool) {
        return
            ACL_TRANSIENT_STORAGE_BASE_SLOT
                .deriveMapping(handle)
                .deriveMapping(account)
                .asBoolean()
                .tload();
    }

    /**
     * Check if an address has persistent access to handle.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Returns `true` if the address has persistent access to a handle and `false` otherwise.
     */
    function _isAllowedPersistent(bytes32 handle, address account) private view returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.admins[handle][account];
    }
}
