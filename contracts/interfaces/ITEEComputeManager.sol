// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../shared/TEEType.sol";

/**
 * @title ITEEComputeManager
 * @notice Interface for the TEE Compute Manager contract
 */
interface ITEEComputeManager {
    // TODO put common errors in a shared interface.
    error InvalidZeroAddress();
    error InvalidProof(bytes proof, string reason);
    error DivisionByZero();
    error IncompatibleTypes();
    error UnsupportedType();
    error ACLNotAllowed(bytes32 handle, address account);

    event ACLUpdated(address indexed newACL);
    event PlaintextToEncrypted(
        address indexed caller,
        uint256 plaintext,
        uint8 toType,
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
    event Select(
        address indexed caller,
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse,
        bytes32 result
    );

    function setAcl(address newAcl) external;
    function validateProof(bytes32 handle, address signer, bytes calldata proof) external view;
    function acl() external view returns (address);

    /**
     * @notice Converts a plaintext value into an encrypted value
     * @param value The plaintext value to encrypt
     * @param teeType The type of the encrypted value
     * @return The encrypted value
     */
    function plaintextToEncrypted(uint256 value, TEEType teeType) external returns (bytes32);

    /**
     * @notice Computes TEE Add operation
     * @param leftHandOperand Left-hand side operand
     * @param rightHandOperand Right-hand side operand
     * @return result Result handle
     */
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Computes TEE Sub operation
     * @param leftHandOperand Left-hand side operand
     * @param rightHandOperand Right-hand side operand
     * @return result Result handle
     */
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Computes TEE Div operation
     * @param leftHandOperand Left-hand side operand
     * @param rightHandOperand Right-hand side operand (must be non-zero)
     * @return result Result handle
     */
    function div(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Computes TEE Select operation (if-then-else)
     * @param condition Control value (must be Bool type)
     * @param ifTrue Value if condition is true
     * @param ifFalse Value if condition is false
     * @return result Result handle
     */
    function select(
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) external returns (bytes32 result);

    /**
     * @notice Does trivial encryption
     * @param pt Plaintext value to encrypt
     * @param toType Target TEE type
     * @return result Result handle
     */
    function trivialEncrypt(uint256 pt, TEEType toType) external returns (bytes32 result);
}
