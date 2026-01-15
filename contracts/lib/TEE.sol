// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "encrypted-types/EncryptedTypes.sol";

/**
 * @title TEEPrimitive
 * @notice Library providing convenient functions for TEE confidential computations.
 */
library TEE {
        /// @notice Reference to TEE services config
    struct TEEConfig {
        address computeManager;
        address acl;
    }

        // keccak256(abi.encode(uint256(keccak256("nox.storage.TEE.config")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_CONFIG_SLOT =
        0x453ce9972f26c0909dff7e07a33068f25d542621580a28090c38444374459000;

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
}