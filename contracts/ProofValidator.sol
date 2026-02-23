// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Nox} from "./sdk/Nox.sol";
import {TEEType} from "./shared/TypeUtils.sol";

/**
 * @title ProofValidator
 * @notice Aapplication contract that validates a handle proof issued by the gateway
 * and grants permanent ACL access to the handle owner.
 */
contract ProofValidator {
    // ============ External functions ============

    /**
     * @notice Validates a handle proof and grants permanent ACL access to the owner.
     * @dev The proof must have been issued by the gateway for this contract as the `app`.
     *      After validation, the owner receives persistent access to the handle via ACL.allow.
     * @param handle The encrypted handle to validate.
     * @param owner The address of the handle owner encoded in the proof.
     * @param proof The 137-byte EIP-712 proof issued by the gateway.
     * @param teeType The expected TEE type of the handle.
     */
    function validateAndAllow(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) external {
        Nox._compute().validateProof(handle, owner, proof, teeType);
        Nox._acl().allow(handle, owner);
    }
}
