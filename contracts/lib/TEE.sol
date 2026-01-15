// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../shared/TEEType.sol";
import "../interfaces/ITEEComputeManager.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title TEE
 * @notice Library providing convenient functions for TEE confidential computations.
 */
library TEE {
    /// @notice Reference to TEE services config
    struct TEEConfig {
        address computeManager;
        address acl;
    }

    // keccak256(abi.encode(uint256(keccak256("nox.storage.TEE.config")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_CONFIG_SLOT = 0x453ce9972f26c0909dff7e07a33068f25d542621580a28090c38444374459000;

    /// @notice Emitted when TEE services config is set
    event TEEServicesConfigSet(address computeManager, address acl);

    /// @notice Returned if TEE services are not configured
    error TEEServicesNotConfigured();

    /**
     * @notice Sets the TEE services configuration
     * @param _config TEE services configuration struct
     */
    function setTEEStorage(TEEConfig memory _config) internal {
        TEEConfig storage $ = _getTEEStorage();
        $.computeManager = _config.computeManager;
        $.acl = _config.acl;
        emit TEEServicesConfigSet(_config.computeManager, _config.acl);
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

    // ============ Trivial Encryption Functions ============
    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function asEbool(bool value) internal returns (ebool) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.computeManager == address(0)) revert TEEServicesNotConfigured();
        return ebool.wrap(ITEEComputeManager($.computeManager).trivialEncrypt(value ? 1 : 0, TEEType.Bool));
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function asEaddress(address value) internal returns (eaddress) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.computeManager == address(0)) revert TEEServicesNotConfigured();
        return eaddress.wrap(ITEEComputeManager($.computeManager).trivialEncrypt(uint256(uint160(value)), TEEType.Uint160));
    }
    
    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function asEuint256(uint256 value) internal returns (euint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.computeManager == address(0)) revert TEEServicesNotConfigured();
        return euint256.wrap(ITEEComputeManager($.computeManager).trivialEncrypt(value, TEEType.Uint256));
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function asEint256(int256 value) internal returns (eint256) {
        TEEConfig storage $ = _getTEEStorage();
        if ($.computeManager == address(0)) revert TEEServicesNotConfigured();
        return eint256.wrap(ITEEComputeManager($.computeManager).trivialEncrypt(uint256(value), TEEType.Int256));
    }
}
