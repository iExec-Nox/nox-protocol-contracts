// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TEEType} from "./TypeUtils.sol";

library HandleUtils {
    /// @dev Bit 0 of the attrs byte. When set, the handle is guaranteed unique on-chain.
    bytes1 internal constant ATTR_IS_UNIQUE_HANDLE = 0x01;

    /**
     * @notice Checks if a handle is a public handle (isUniqueHandle bit == 0).
     * A public handle wraps a plaintext value known on-chain, has no ACL,
     * and is accessible by everyone.
     * @param handle The handle to check
     * @return True if the handle is a public handle
     */
    function isPublicHandle(bytes32 handle) internal pure returns (bool) {
        return (handle[6] & ATTR_IS_UNIQUE_HANDLE) == 0;
    }

    /**
     * @notice Returns the zero handle for the given TEE type on the current chain.
     * The zero handle represents the default zero value for a given type and is a public handle.
     * It follows the standard handle format but with a zeroed pre-handle:
     *   [0]=version(0x00)  [1-4]=chainId  [5]=teeType  [6]=attrs(0x00)  [7-31]=0x00..00
     * @param teeType The TEE type to encode
     * @return The typed null handle
     */
    function zeroHandle(TEEType teeType) internal view returns (bytes32) {
        return
            // [0]=version is implicitly 0x00
            (bytes32(bytes4(uint32(block.chainid))) >> (1 * 8)) |
            (bytes32(bytes1(uint8(teeType))) >> (5 * 8));
    }
}
