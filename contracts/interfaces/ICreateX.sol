// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title ICreateX
 * @notice Interface for the CreateX deterministic deployment factory.
 * @dev CreateX is deployed at 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed on most EVM chains.
 *      See: https://github.com/pcaversaccio/createx
 */
interface ICreateX {
    /**
     * @notice Deploys a contract using CREATE2.
     * @param salt The salt value for deterministic address calculation.
     * @param initCode The contract creation bytecode (bytecode + constructor arguments).
     * @return newContract The address of the deployed contract.
     */
    function deployCreate2(
        bytes32 salt,
        bytes memory initCode
    ) external payable returns (address newContract);

    /**
     * @notice Computes the deterministic address of a contract deployed via CREATE2.
     * @param salt The salt value used for deployment.
     * @param initCodeHash The keccak256 hash of the contract creation bytecode.
     * @return The computed address where the contract would be deployed.
     */
    function computeCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash
    ) external view returns (address);

    /**
     * @notice Computes the deterministic address of a contract deployed via CREATE2.
     * @param salt The salt value used for deployment.
     * @param initCodeHash The keccak256 hash of the contract creation bytecode.
     * @param deployer The address of the deployer (CreateX factory address).
     * @return The computed address where the contract would be deployed.
     */
    function computeCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address deployer
    ) external pure returns (address);
}
