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
     * @notice Converts a plaintext value into an encrypted value
     * @param value The plaintext value to encrypt
     * @param teeType The type of the encrypted value
     * @return The encrypted value
     */
    function plaintextToEncrypted(uint256 value, TEEType teeType) external returns (bytes32);
}
