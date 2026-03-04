// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Nox} from "./sdk/Nox.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title ProofValidator
 * @notice Application contract that validates a handle proof issued by the gateway
 * and grants permanent ACL access to the caller.
 */
contract ProofValidator {
    // ============ External functions ============

    /**
     * @notice Validates an ebool handle proof and grants ACL access to the caller.
     * @param handle The external encrypted boolean handle.
     * @param proof The EIP-712 proof issued by the gateway.
     */
    function validateAndAllowEbool(externalEbool handle, bytes calldata proof) external {
        ebool h = Nox.fromExternal(handle, proof);
        Nox.allow(h, msg.sender);
    }

    /**
     * @notice Validates an euint16 handle proof and grants ACL access to the caller.
     * @param handle The external encrypted uint16 handle.
     * @param proof The EIP-712 proof issued by the gateway.
     */
    function validateAndAllowEuint16(externalEuint16 handle, bytes calldata proof) external {
        euint16 h = Nox.fromExternal(handle, proof);
        Nox.allow(h, msg.sender);
    }

    /**
     * @notice Validates an euint256 handle proof and grants ACL access to the caller.
     * @param handle The external encrypted uint256 handle.
     * @param proof The EIP-712 proof issued by the gateway.
     */
    function validateAndAllowEuint256(externalEuint256 handle, bytes calldata proof) external {
        euint256 h = Nox.fromExternal(handle, proof);
        Nox.allow(h, msg.sender);
    }

    /**
     * @notice Validates an eint16 handle proof and grants ACL access to the caller.
     * @param handle The external encrypted int16 handle.
     * @param proof The EIP-712 proof issued by the gateway.
     */
    function validateAndAllowEint16(externalEint16 handle, bytes calldata proof) external {
        eint16 h = Nox.fromExternal(handle, proof);
        Nox.allow(h, msg.sender);
    }

    /**
     * @notice Validates an eint256 handle proof and grants ACL access to the caller.
     * @param handle The external encrypted int256 handle.
     * @param proof The EIP-712 proof issued by the gateway.
     */
    function validateAndAllowEint256(externalEint256 handle, bytes calldata proof) external {
        eint256 h = Nox.fromExternal(handle, proof);
        Nox.allow(h, msg.sender);
    }
}
