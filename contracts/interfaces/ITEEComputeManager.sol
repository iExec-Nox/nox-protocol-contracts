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

    event ACLUpdated(address indexed newACL);

    function setAcl(address newAcl) external;
    function validateProof(bytes32 handle, address signer, bytes calldata proof) external view;
    function acl() external view returns (address);

    /**
     * @notice Converts a plaintext value into an encrypted handle
     * @param pt Plaintext value to encrypt
     * @param toType Target TEE type
     * @return result Result handle
     */
    function plaintextToEncrypted(uint256 pt, TEEType toType) external returns (bytes32 result);

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
}
