// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../shared/TEEType.sol";
import "../interfaces/ITEEComputeManager.sol";
import "../interfaces/IACL.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title TEE
 * @notice Library providing convenient functions for TEE confidential computations.
 * @dev If an invalid or non-existent handle is passed to any function in the Nox protocol,
 *      the transaction will revert as it will not be recognized by the ACL.
 */
library TEE {
    /// @notice Reference to TEE services config
    struct TEEConfig {
        address teeComputeManager;
        address acl;
    }

    /// keccak256(abi.encode(uint256(keccak256("nox.storage.TEE.config")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_CONFIG_SLOT =
        0x453ce9972f26c0909dff7e07a33068f25d542621580a28090c38444374459000;

    /// @notice Emitted when TEE services config is set
    event TEEServicesConfigSet(address teeComputeManager, address acl);

    /// @notice Returned if TEE services are not configured
    error TEEServicesNotConfigured();

    // ============ Trivial Encryption Functions ============
    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function toEbool(bool value) internal returns (ebool) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.teeComputeManager == address(0)) revert TEEServicesNotConfigured();
        return
            ebool.wrap(
                ITEEComputeManager($.teeComputeManager).trivialEncrypt(value ? 1 : 0, TEEType.Bool)
            );
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function toEaddress(address value) internal returns (eaddress) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.teeComputeManager == address(0)) revert TEEServicesNotConfigured();
        return
            eaddress.wrap(
                ITEEComputeManager($.teeComputeManager).trivialEncrypt(
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
        if ($.teeComputeManager == address(0)) revert TEEServicesNotConfigured();
        return
            euint256.wrap(
                ITEEComputeManager($.teeComputeManager).trivialEncrypt(value, TEEType.Uint256)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.teeComputeManager == address(0)) revert TEEServicesNotConfigured();
        return
            eint256.wrap(
                ITEEComputeManager($.teeComputeManager).trivialEncrypt(
                    uint256(value),
                    TEEType.Int256
                )
            );
    }

    // ============ PERMISSION MANAGEMENT ============
    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal returns (eaddress) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(eaddress.unwrap(value), address(this));
        }
        return value;
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal returns (eaddress) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allowTransient(eaddress.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(ebool value, address account) internal returns (ebool) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(ebool.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal returns (ebool) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(ebool.unwrap(value), address(this));
        }
        return value;
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal returns (ebool) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allowTransient(ebool.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal returns (euint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(euint256.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal returns (euint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(euint256.unwrap(value), address(this));
        }
        return value;
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal returns (euint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allowTransient(euint256.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal returns (eint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(eint256.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal returns (eint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(eint256.unwrap(value), address(this));
        }
        return value;
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal returns (eint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allowTransient(eint256.unwrap(value), account);
        }
        return value;
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal returns (eaddress) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.acl != address(0)) {
            IACL($.acl).allow(eaddress.unwrap(value), account);
        }
        return value;
    }

    // ============ TEE CONFIGURATION ============
    /**
     * @notice Sets the TEE services configuration
     * @param _config TEE services configuration struct
     */
    function setTEEStorage(TEEConfig memory _config) internal {
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
