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
    /// @notice Reference to TEE services config
    struct TEEConfig {
        address teeComputeManager;
        address acl;
    }

    /// keccak256(abi.encode(uint256(keccak256("nox.storage.TEEConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_CONFIG_SLOT =
        0x55fc6f3f35af33b9f7b1cd69927b3b40430f605ab4fc44fcf6cbc2ec120ec900;

    /// @notice Emitted when TEE services config is set
    event TEEServicesConfigSet(address teeComputeManager, address acl);

    // ============ Trivial Encryption Functions ============

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

    // ============ TEE CONFIGURATION ============

    /**
     * @notice Sets the TEE services configuration
     * @param _config TEE services configuration struct
     */
    function setTEEStorage(TEEConfig memory _config) internal {
        if (_config.teeComputeManager == address(0)) {
            revert IErrors.InvalidZeroAddress();
        }
        if (_config.acl == address(0)) {
            revert IErrors.InvalidZeroAddress();
        }
        TEEConfig storage $ = _getTEEStorage();
        $.teeComputeManager = _config.teeComputeManager;
        $.acl = _config.acl;
        emit TEEServicesConfigSet(_config.teeComputeManager, _config.acl);
    }

    function _getTEEStorage() private pure returns (TEEConfig storage config) {
        bytes32 slot = TEE_CONFIG_SLOT;
        assembly {
            config.slot := slot
        }
    }

    function _teeComputeManager() private view returns (ITEEComputeManager) {
        // TODO read from constant address to save gas.
        TEEConfig storage $ = _getTEEStorage();
        return ITEEComputeManager($.teeComputeManager);
    }

    function _acl() private view returns (IACL) {
        TEEConfig storage $ = _getTEEStorage();
        return IACL($.acl);
    }
}
