// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IErrors} from "./IErrors.sol";
import {TEEType} from "../shared/TEEType.sol";

/**
 * @title ITEEComputeManager
 * @notice Interface for the TEE Compute Manager contract
 */
interface ITEEComputeManager is IErrors {
    error InvalidProof(bytes proof, string reason);
    error IncompatibleTypes();
    error UnsupportedType();
    error ACLNotAllowed(bytes32 handle, address account);

    event ACLUpdated(address indexed newACL);
    event GatewayUpdated(address indexed newGateway);
    event Add(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );

    enum Operator {
        Add
    }

    function setAcl(address newAcl) external;
    function setGateway(address gatewayAddress) external;

    /**
     * @notice Converts a plaintext value into an encrypted value
     * @param value The plaintext value to encrypt
     * @param teeType The type of the encrypted value
     * @return The encrypted value
     */
    function plaintextToEncrypted(uint256 value, TEEType teeType) external returns (bytes32);

    /**
     * @notice Computes TEE Add operation
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Result handle
     */
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    // TODO for all safe operations, determine which cyphertexte linked to the new handle to return
    // as result in case of failure.
    /**
     * @notice Performs an addition between two encrypted values with safety checks.
     * The operation fails in the case of overflows.
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return success Whether the operation was successful
     * @return result Result handle
     */
    function safeAdd(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result);

    /**
     * @notice Performs a subtraction between two encrypted values with safety checks.
     * The operation fails in the case of underflow.
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return success Whether the operation was successful
     * @return result Result handle
     */
    function safeSub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result);

    /**
     * @notice Selects between two encrypted values based on a condition
     * @param condition Condition handle
     * @param ifTrue Value handle if condition is true
     * @param ifFalse Value handle if condition is false
     * @return result Selected value handle
     */
    function select(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external returns (bytes32);

    function validateProof(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) external;

    function domainSeparator() external view returns (bytes32);
    function acl() external view returns (address);
    function gateway() external view returns (address);
}
