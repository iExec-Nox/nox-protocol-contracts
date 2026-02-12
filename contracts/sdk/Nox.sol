// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {TEEType} from "../shared/TypeUtils.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";
import {IACL} from "../interfaces/IACL.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title Nox
 * @notice Library providing convenient functions for TEE confidential computations.
 * @dev If an invalid or non-existent handle is passed to any function in the Nox protocol,
 *      the transaction will revert as it will not be recognized by the ACL.
 *
 *      NOX_COMPUTE and ACL are deterministic across all EVM chains using the CreateX factory.
 *      These addresses are derived from the CREATE2 salt configured in hardhat.config.ts.
 *
 *      IMPORTANT: If a fresh deployment is performed (not an upgrade), the proxy addresses will change.
 *      In that case, update these constants with the new deployed addresses.
 */
library Nox {
    // TODO: Update these addresses after deploying with the production salt.
    INoxCompute internal constant NOX_COMPUTE =
        INoxCompute(0xF932D65622b6Ea00E100aAD447fd863e3A197b61);
    IACL internal constant ACL = IACL(0x192f11A5B56aB295ea176FBFFCb96AF99468e955);

    // =========== Handle initialization checks ============

    /**
     * @dev Checks if an encrypted boolean handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted boolean handle
     */
    function isInitialized(ebool handle) internal pure returns (bool) {
        return ebool.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted address handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted address handle
     */
    function isInitialized(eaddress handle) internal pure returns (bool) {
        return eaddress.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted uint256 handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted uint256 handle
     */
    function isInitialized(euint256 handle) internal pure returns (bool) {
        return euint256.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted int256 handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted int256 handle
     */
    function isInitialized(eint256 handle) internal pure returns (bool) {
        return eint256.unwrap(handle) != 0;
    }

    // ============ Trivial Encryption Functions ============

    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function toEbool(bool value) internal returns (ebool) {
        return ebool.wrap(NOX_COMPUTE.plaintextToEncrypted(bytes32(uint256(value ? 1 : 0)), TEEType.Bool));
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function toEaddress(address value) internal returns (eaddress) {
        return
            eaddress.wrap(
                NOX_COMPUTE.plaintextToEncrypted(bytes32(uint256(uint160(value))), TEEType.Address)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function toEuint256(uint256 value) internal returns (euint256) {
        return euint256.wrap(NOX_COMPUTE.plaintextToEncrypted(bytes32(value), TEEType.Uint256));
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        return eint256.wrap(NOX_COMPUTE.plaintextToEncrypted(bytes32(uint256(value)), TEEType.Int256));
    }

    // ============ Handle validation ============

    function fromExternal(
        externalEuint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint256) {
        bytes32 handle = externalEuint256.unwrap(externalHandle);
        NOX_COMPUTE.validateProof(handle, msg.sender, handleProof, TEEType.Uint256);
        return euint256.wrap(handle);
    }

    // ============ Arithmetic primitives ============
    // TODO add primitives for all numeric types.

    function add(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(NOX_COMPUTE.add(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function sub(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(NOX_COMPUTE.sub(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function mul(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(NOX_COMPUTE.mul(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function div(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(NOX_COMPUTE.div(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function safeAdd(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = NOX_COMPUTE.safeAdd(
            euint256.unwrap(a),
            euint256.unwrap(b)
        );
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeSub(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = NOX_COMPUTE.safeSub(
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
                NOX_COMPUTE.select(
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
        ACL.allow(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal {
        ACL.allow(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal {
        ACL.allow(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal {
        ACL.allow(eint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal {
        ACL.allow(ebool.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal {
        ACL.allow(euint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal {
        ACL.allow(eint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal {
        ACL.allow(eaddress.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal {
        ACL.allowTransient(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal {
        ACL.allowTransient(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal {
        ACL.allowTransient(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal {
        ACL.allowTransient(eint256.unwrap(value), account);
    }

    // ============ VIEWER MANAGEMENT ============

    /**
     * @dev Adds a viewer for an ebool handle.
     */
    function addViewer(ebool value, address viewer) internal {
        ACL.addViewer(ebool.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eaddress handle.
     */
    function addViewer(eaddress value, address viewer) internal {
        ACL.addViewer(eaddress.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an euint256 handle.
     */
    function addViewer(euint256 value, address viewer) internal {
        ACL.addViewer(euint256.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eint256 handle.
     */
    function addViewer(eint256 value, address viewer) internal {
        ACL.addViewer(eint256.unwrap(value), viewer);
    }

    // ============ PUBLIC DECRYPTION ============

    /**
     * @dev Marks an ebool handle as publicly decryptable.
     */
    function allowPublicDecryption(ebool value) internal {
        ACL.allowPublicDecryption(ebool.unwrap(value));
    }

    /**
     * @dev Marks an eaddress handle as publicly decryptable.
     */
    function allowPublicDecryption(eaddress value) internal {
        ACL.allowPublicDecryption(eaddress.unwrap(value));
    }

    /**
     * @dev Marks an euint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint256 value) internal {
        ACL.allowPublicDecryption(euint256.unwrap(value));
    }

    /**
     * @dev Marks an eint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint256 value) internal {
        ACL.allowPublicDecryption(eint256.unwrap(value));
    }

    // ============ AUTHORIZATION QUERIES ============

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(ebool handle, address account) internal view returns (bool) {
        return ACL.isAllowed(ebool.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eaddress handle, address account) internal view returns (bool) {
        return ACL.isAllowed(eaddress.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint256 handle, address account) internal view returns (bool) {
        return ACL.isAllowed(euint256.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eint256 handle, address account) internal view returns (bool) {
        return ACL.isAllowed(eint256.unwrap(handle), account);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(ebool handle, address viewer) internal view returns (bool) {
        return ACL.isViewer(ebool.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eaddress handle, address viewer) internal view returns (bool) {
        return ACL.isViewer(eaddress.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(euint256 handle, address viewer) internal view returns (bool) {
        return ACL.isViewer(euint256.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eint256 handle, address viewer) internal view returns (bool) {
        return ACL.isViewer(eint256.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(ebool handle) internal view returns (bool) {
        return ACL.isPubliclyDecryptable(ebool.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eaddress handle) internal view returns (bool) {
        return ACL.isPubliclyDecryptable(eaddress.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(euint256 handle) internal view returns (bool) {
        return ACL.isPubliclyDecryptable(euint256.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eint256 handle) internal view returns (bool) {
        return ACL.isPubliclyDecryptable(eint256.unwrap(handle));
    }
}
