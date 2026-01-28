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

    event ACLUpdated(address indexed newACL);
    event GatewayUpdated(address indexed newGateway);

    function setAcl(address newAcl) external;
    function setGateway(address gatewayAddress) external;

    /**
     * @notice Converts a plaintext value into an encrypted value
     * @param value The plaintext value to encrypt
     * @param teeType The type of the encrypted value
     * @return The encrypted value
     */
    function plaintextToEncrypted(uint256 value, TEEType teeType) external returns (bytes32);

    function validateProof(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) external;

    function safeAdd(bytes32 a, bytes32 b) external returns (bytes32 success, bytes32 result);
    function safeSub(bytes32 a, bytes32 b) external returns (bytes32 success, bytes32 result);
    function select(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external returns (bytes32);

    function domainSeparator() external view returns (bytes32);
    function acl() external view returns (address);
    function gateway() external view returns (address);
}
