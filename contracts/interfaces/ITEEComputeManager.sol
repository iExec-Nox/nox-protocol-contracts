// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IErrors} from "./IErrors.sol";
import {IACL} from "./IACL.sol";
import {TEEType} from "../shared/TypeUtils.sol";

/**
 * @title ITEEComputeManager
 * @notice Interface for the TEE Compute Manager contract
 */
interface ITEEComputeManager is IErrors {
    error InvalidProof(bytes proof, string reason);
    error IncompatibleTypes();

    error ACLNotAllowed(bytes32 handle, address account);

    event GatewayUpdated(address indexed newGateway);

    event PlaintextToEncrypted(
        address indexed caller,
        uint256 plaintext,
        TEEType toType,
        bytes32 result
    );
    event Add(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Sub(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Div(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event SafeAdd(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 success,
        bytes32 result
    );
    event SafeSub(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 success,
        bytes32 result
    );
    event Select(
        address indexed caller,
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse,
        bytes32 result
    );

    enum Operator {
        PlaintextToEncrypted,
        Add,
        Sub,
        Div,
        SafeAdd,
        SafeSub,
        Select
    }

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

    /**
     * @notice Performs a subtraction between two encrypted values without safety checks.
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Result handle
     */
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Performs a division between two encrypted values
     * @param numerator Value to be divided
     * @param denominator Value to divide by
     * @return result Result handle
     */
    function div(bytes32 numerator, bytes32 denominator) external returns (bytes32 result);

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
    function ACL() external view returns (IACL);
    function gateway() external view returns (address);

    /// @dev See {IACL-isAllowed}
    function isAllowed(bytes32 handle, address account) external view returns (bool);

    /// @dev See {IACL-isViewer}
    function isViewer(bytes32 handle, address viewer) external view returns (bool);

    /// @dev See {IACL-isPubliclyDecryptable}
    function isPubliclyDecryptable(bytes32 handle) external view returns (bool);
}
