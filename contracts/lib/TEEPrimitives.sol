// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {TEEType} from "../shared/TypeUtils.sol";
import {ITEEComputeManager} from "../interfaces/ITEEComputeManager.sol";
import {IACL} from "../interfaces/IACL.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title TEEPrimitives
 * @notice Library providing convenient functions for TEE confidential computations.
 * @dev If an invalid or non-existent handle is passed to any function in the Nox protocol,
 *      the transaction will revert as it will not be recognized by the ACL.
 *
 *      TEE_COMPUTE_MANAGER and ACL_ADDRESS are deterministic across all EVM chains using the CreateX factory.
 *      These addresses are derived from the CREATE2 salt configured in hardhat.config.ts.
 *
 *      IMPORTANT: If a fresh deployment is performed (not an upgrade), the proxy addresses will change.
 *      In that case, update these constants with the new deployed addresses.
 */
library TEEPrimitives {
    // TODO: Update these addresses after deploying with the production salt.
    address internal constant TEE_COMPUTE_MANAGER = 0xf07E9032F06E44e2c04930484aD0C8865779e08e;
    address internal constant ACL_ADDRESS = 0x8bEa38F8915c35E61bd3c95a23A7370d5B344F7b;

    // ============ Trivial Encryption Functions ============

    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function toEbool(bool value) internal returns (ebool) {
        return
            ebool.wrap(
                ITEEComputeManager(TEE_COMPUTE_MANAGER).plaintextToEncrypted(
                    value ? 1 : 0,
                    TEEType.Bool
                )
            );
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function toEaddress(address value) internal returns (eaddress) {
        return
            eaddress.wrap(
                ITEEComputeManager(TEE_COMPUTE_MANAGER).plaintextToEncrypted(
                    uint256(uint160(value)),
                    TEEType.Address
                )
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function toEuint256(uint256 value) internal returns (euint256) {
        return
            euint256.wrap(
                ITEEComputeManager(TEE_COMPUTE_MANAGER).plaintextToEncrypted(value, TEEType.Uint256)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        return
            eint256.wrap(
                ITEEComputeManager(TEE_COMPUTE_MANAGER).plaintextToEncrypted(
                    uint256(value),
                    TEEType.Int256
                )
            );
    }

    // ============ Handle conversion ============

    function fromExternal(
        externalEuint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint256) {
        bytes32 handle = externalEuint256.unwrap(externalHandle);
        ITEEComputeManager(TEE_COMPUTE_MANAGER).validateProof(
            handle,
            msg.sender,
            handleProof,
            TEEType.Uint256
        );
        return euint256.wrap(handle);
    }

    // ============ Arithmetic primitives ============

    function add(euint256 a, euint256 b) internal returns (euint256) {
        return
            euint256.wrap(
                ITEEComputeManager(TEE_COMPUTE_MANAGER).add(euint256.unwrap(a), euint256.unwrap(b))
            );
    }

    function sub(euint256 a, euint256 b) internal returns (euint256) {
        return
            euint256.wrap(
                ITEEComputeManager(TEE_COMPUTE_MANAGER).sub(euint256.unwrap(a), euint256.unwrap(b))
            );
    }

    function safeAdd(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = ITEEComputeManager(TEE_COMPUTE_MANAGER).safeAdd(
            euint256.unwrap(a),
            euint256.unwrap(b)
        );
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeSub(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = ITEEComputeManager(TEE_COMPUTE_MANAGER).safeSub(
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
                ITEEComputeManager(TEE_COMPUTE_MANAGER).select(
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
        IACL(ACL_ADDRESS).allow(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal {
        IACL(ACL_ADDRESS).allow(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal {
        IACL(ACL_ADDRESS).allow(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal {
        IACL(ACL_ADDRESS).allow(eint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal {
        IACL(ACL_ADDRESS).allow(ebool.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal {
        IACL(ACL_ADDRESS).allow(euint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal {
        IACL(ACL_ADDRESS).allow(eint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal {
        IACL(ACL_ADDRESS).allow(eaddress.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal {
        IACL(ACL_ADDRESS).allowTransient(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal {
        IACL(ACL_ADDRESS).allowTransient(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal {
        IACL(ACL_ADDRESS).allowTransient(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal {
        IACL(ACL_ADDRESS).allowTransient(eint256.unwrap(value), account);
    }

    // ============ PUBLIC DECRYPTION ============
    /**
     * @dev Marks an ebool handle as publicly decryptable.
     */
    function allowPublicDecryption(ebool value) internal {
        IACL(ACL_ADDRESS).allowPublicDecryption(ebool.unwrap(value));
    }

    /**
     * @dev Marks an eaddress handle as publicly decryptable.
     */
    function allowPublicDecryption(eaddress value) internal {
        IACL(ACL_ADDRESS).allowPublicDecryption(eaddress.unwrap(value));
    }

    /**
     * @dev Marks an euint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint256 value) internal {
        IACL(ACL_ADDRESS).allowPublicDecryption(euint256.unwrap(value));
    }

    /**
     * @dev Marks an eint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint256 value) internal {
        IACL(ACL_ADDRESS).allowPublicDecryption(eint256.unwrap(value));
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint256 handle, address account) internal view returns (bool) {
        return IACL(ACL_ADDRESS).isAllowed(euint256.unwrap(handle), account);
    }
}
