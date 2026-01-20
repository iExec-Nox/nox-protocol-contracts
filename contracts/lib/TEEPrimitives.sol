// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../shared/TEEType.sol";
import "../interfaces/ITEEComputeManager.sol";
import "../interfaces/IACL.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title TEEPrimitives
 * @notice Library providing convenient functions for TEE confidential computations.
 * @dev If an invalid or non-existent handle is passed to any function in the Nox protocol,
 *      the transaction will revert as it will not be recognized by the ACL.
 */
library TEEPrimitives {
    /// @notice Reference to TEE services config
    struct TEEConfig {
        address teeComputeManager;
        address acl;
    }

    /// keccak256(abi.encode(uint256(keccak256("nox.storage.TEEConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_CONFIG_SLOT =
        0xe62ace9d5e38a7cc1c4b32793b4903144d8216801be242610d55d7ec48c6ff00;

    /// @notice Emitted when TEE services config is set
    event TEEServicesConfigSet(address teeComputeManager, address acl);

    /// @notice Returned if TEE services are not configured
    error TEEServicesNotConfigured();

    /// @notice Returned if ACL is not configured
    error ACLNotConfigured();

    // ============ Trivial Encryption Functions ============
    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function toEbool(bool value) internal returns (ebool) {
        TEEConfig storage $ = _getTEEStorage();
        return
            ebool.wrap(
                ITEEComputeManager($.teeComputeManager).plaintextToEncrypted(
                    value ? 1 : 0,
                    TEEType.Bool
                )
            );
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function toEaddress(address value) internal returns (eaddress) {
        TEEConfig storage $ = _getTEEStorage();
        return
            eaddress.wrap(
                ITEEComputeManager($.teeComputeManager).plaintextToEncrypted(
                    uint256(uint160(value)),
                    TEEType.Uint160
                )
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function toEuint256(uint256 value) internal returns (euint256) {
        TEEConfig storage $ = _getTEEStorage();
        return
            euint256.wrap(
                ITEEComputeManager($.teeComputeManager).plaintextToEncrypted(value, TEEType.Uint256)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        TEEConfig storage $ = _getTEEStorage();
        return
            eint256.wrap(
                ITEEComputeManager($.teeComputeManager).plaintextToEncrypted(
                    uint256(value),
                    TEEType.Int256
                )
            );
    }

    // ============ PERMISSION MANAGEMENT ============
    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(ebool value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(eint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(ebool.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(euint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(eint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allow(eaddress.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allowTransient(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allowTransient(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allowTransient(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal {
        TEEConfig storage $ = _getTEEStorage();
        IACL($.acl).allowTransient(eint256.unwrap(value), account);
    }

    // ============ TEE CONFIGURATION ============
    /**
     * @notice Sets the TEE services configuration
     * @param _config TEE services configuration struct
     */
    function setTEEStorage(TEEConfig memory _config) internal {
        if (_config.teeComputeManager == address(0)) revert TEEServicesNotConfigured();
        if (_config.acl == address(0)) revert ACLNotConfigured();
        TEEConfig storage $ = _getTEEStorage();
        $.teeComputeManager = _config.teeComputeManager;
        $.acl = _config.acl;
        emit TEEServicesConfigSet(_config.teeComputeManager, _config.acl);
    }

    /**
     * @notice Gets the TEE services configuration
     * @return config The TEE services configuration
     */
    function _getTEEStorage() private pure returns (TEEConfig storage config) {
        bytes32 slot = TEE_CONFIG_SLOT;
        assembly {
            config.slot := slot
        }
    }
}
