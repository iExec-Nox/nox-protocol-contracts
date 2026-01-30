// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

enum TEEType {
    Bool,
    Address,
    Uint160,
    Uint256,
    Int256
}

error UnsupportedType();

library TypeUtils {
    /**
     * @notice Extracts the TEE type from a handle.
     * The type is stored at byte position 30 in the handle.
     * @param handle The handle to extract the type from
     * @return The TEEType encoded in the handle
     */
    function typeOf(bytes32 handle) internal pure returns (TEEType) {
        return TEEType(uint8(handle[30]));
    }

    /**
     * @notice Validates that a TEE type is encryptable (can be used in plaintextToEncrypted).
     * Reverts with UnsupportedType if the type is not encryptable.
     * @param teeType The TEE type to validate
     */
    function validateEncryptableType(TEEType teeType) internal pure {
        uint256 supportedTypes = (1 << uint8(TEEType.Bool)) +
            (1 << uint8(TEEType.Address)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
        if (((1 << uint8(teeType)) & supportedTypes) == 0) {
            revert UnsupportedType();
        }
    }

    /**
     * @notice Validates that a TEE type is supported for arithmetic operations.
     * Reverts with UnsupportedType if the type is not arithmetic.
     * @param teeType The TEE type to validate
     */
    function validateArithmeticType(TEEType teeType) internal pure {
        uint256 supportedTypes = (1 << uint8(TEEType.Uint256)) + (1 << uint8(TEEType.Int256));
        if (((1 << uint8(teeType)) & supportedTypes) == 0) {
            revert UnsupportedType();
        }
    }
}
