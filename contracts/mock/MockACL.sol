// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title MockACL
 * @dev Mock ACL contract for testing TEEComputeManager functionality
 */
contract MockACL {
    mapping(bytes32 => mapping(address => bool)) public allowed;

    function setAllowed(bytes32 handle, address account, bool value) external {
        allowed[handle][account] = value;
    }

    function isAllowed(bytes32 handle, address account) external view returns (bool) {
        return allowed[handle][account];
    }

    function allowTransient(bytes32, address) external pure {
        // No-op for testing
    }
}
