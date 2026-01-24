// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../shared/TEEType.sol";

/**
 * @title ITEEComputeManager
 * @notice Interface for the TEE Compute Manager contract
 */
interface ITEEComputeManager {
    enum Operators {
        teeAdd,
        teeSub,
        teeDiv
    }

    // TODO put common errors in a shared interface.
    error InvalidZeroAddress();
    error InvalidProof(bytes proof, string reason);
    error DivisionByZero();
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

    function validateProof(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) external view;
    function domainSeparator() external view returns (bytes32);
    function acl() external view returns (address);
    function gateway() external view returns (address);
}
