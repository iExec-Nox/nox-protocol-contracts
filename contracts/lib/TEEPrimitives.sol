// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {TEEType} from "../shared/TypeUtils.sol";
import {ITEEComputeManager} from "../interfaces/ITEEComputeManager.sol";
import {IACL} from "../interfaces/IACL.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title TEEPrimitives
 * @notice Library providing convenient functions for TEE confidential computations.
 * @dev If an invalid or non-existent handle is passed to any function in the Nox protocol,
 *      the transaction will revert as it will not be recognized by the ACL.
 */
library TEEPrimitives {
    // TODO use CreateX and hardcode addresses in library.
    /// @notice Reference to Nox protocol contracts
    struct NoxConfigStorage {
        address teeComputeManager;
        address acl;
    }

    /// keccak256(abi.encode(uint256(keccak256("nox.storage.NoxConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NOX_CONFIG_SLOT =
        0xc012b247b131c2f4d52be19d2c9d06153fabbe1dd8bf07b88202b0c16b15ee00;

    /// @notice Emitted when Nox protocol config is updated
    event NoxConfigSet(address teeComputeManager, address acl);

    // ============ Trivial Encryption Functions ============

    function isInitialized(euint256 handle) internal pure returns (bool) {
        return euint256.unwrap(handle) != 0;
    }

    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function toEbool(bool value) internal returns (ebool) {
        return ebool.wrap(_teeComputeManager().plaintextToEncrypted(value ? 1 : 0, TEEType.Bool));
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function toEaddress(address value) internal returns (eaddress) {
        return
            eaddress.wrap(
                _teeComputeManager().plaintextToEncrypted(uint256(uint160(value)), TEEType.Address)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function toEuint256(uint256 value) internal returns (euint256) {
        return euint256.wrap(_teeComputeManager().plaintextToEncrypted(value, TEEType.Uint256));
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        return
            eint256.wrap(_teeComputeManager().plaintextToEncrypted(uint256(value), TEEType.Int256));
    }

    // ============ Handle conversion ============

    function fromExternal(
        externalEuint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint256) {
        bytes32 handle = externalEuint256.unwrap(externalHandle);
        _teeComputeManager().validateProof(handle, msg.sender, handleProof, TEEType.Uint256);
        return euint256.wrap(handle);
    }

    // ============ Arithmetic primitives ============

    function add(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_teeComputeManager().add(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function sub(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_teeComputeManager().sub(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function mul(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_teeComputeManager().mul(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function div(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_teeComputeManager().div(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function safeAdd(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = _teeComputeManager().safeAdd(
            euint256.unwrap(a),
            euint256.unwrap(b)
        );
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeSub(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = _teeComputeManager().safeSub(
            euint256.unwrap(a),
            euint256.unwrap(b)
        );
        return (ebool.wrap(success), euint256.wrap(result));
    }

    // TODO add safeMul and safeDiv.

    function select(
        ebool condition,
        euint256 ifTrue,
        euint256 ifFalse
    ) internal returns (euint256) {
        return
            euint256.wrap(
                _teeComputeManager().select(
                    ebool.unwrap(condition),
                    euint256.unwrap(ifTrue),
                    euint256.unwrap(ifFalse)
                )
            );
    }

    // ============ PERMISSION MANAGEMENT ============

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(ebool value, address account) internal {
        _acl().allow(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal {
        _acl().allow(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal {
        _acl().allow(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal {
        _acl().allow(eint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal {
        _acl().allow(ebool.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal {
        _acl().allow(euint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal {
        _acl().allow(eint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal {
        _acl().allow(eaddress.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal {
        _acl().allowTransient(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal {
        _acl().allowTransient(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal {
        _acl().allowTransient(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal {
        _acl().allowTransient(eint256.unwrap(value), account);
    }

    // ============ PUBLIC DECRYPTION ============
    /**
     * @dev Marks an ebool handle as publicly decryptable.
     */
    function allowPublicDecryption(ebool value) internal {
        _acl().allowPublicDecryption(ebool.unwrap(value));
    }

    /**
     * @dev Marks an eaddress handle as publicly decryptable.
     */
    function allowPublicDecryption(eaddress value) internal {
        _acl().allowPublicDecryption(eaddress.unwrap(value));
    }

    /**
     * @dev Marks an euint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint256 value) internal {
        _acl().allowPublicDecryption(euint256.unwrap(value));
    }

    /**
     * @dev Marks an eint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint256 value) internal {
        _acl().allowPublicDecryption(eint256.unwrap(value));
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint256 handle, address account) internal view returns (bool) {
        return _acl().isAllowed(euint256.unwrap(handle), account);
    }

    // ============ NOX CONFIGURATION ============

    function setNoxConfig(address teeComputeManager) internal {
        if (teeComputeManager == address(0)) {
            revert IErrors.InvalidZeroAddress();
        }
        address acl = address(ITEEComputeManager(teeComputeManager).ACL());
        if (acl == address(0)) {
            revert IErrors.InvalidZeroAddress();
        }
        NoxConfigStorage storage $ = _getNoxConfigStorage();
        $.teeComputeManager = teeComputeManager;
        $.acl = acl;
        emit NoxConfigSet(teeComputeManager, acl);
    }

    function _getNoxConfigStorage() private pure returns (NoxConfigStorage storage config) {
        assembly {
            config.slot := NOX_CONFIG_SLOT
        }
    }

    function _teeComputeManager() private view returns (ITEEComputeManager) {
        // TODO read from constant address to save gas.
        NoxConfigStorage storage $ = _getNoxConfigStorage();
        return ITEEComputeManager($.teeComputeManager);
    }

    function _acl() private view returns (IACL) {
        NoxConfigStorage storage $ = _getNoxConfigStorage();
        return IACL($.acl);
    }
}
