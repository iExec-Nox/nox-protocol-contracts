// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../ACL.sol";
import "../shared/TEEType.sol";
import "forge-std/Test.sol";

/**
 * @title TEEComputeManagerMock
 * @dev Mock TEEComputeManager contract for testing ACL functionality with helper functions
 * This contract acts as a mock TEE Compute Manager to test ACL permissions
 */
contract TEEComputeManagerMock is Test {
    ACL public immutable acl;

    constructor() {
        // Set this contract as teeComputeManager so it can call allowTransient/allow
        acl = new ACL(address(this));
    }

    /**
     * @dev Mock trivialEncrypt function that returns sequential handles
     * @param value The plaintext value to encrypt (unused in mock)
     * @param teeType The type of the encrypted value (unused in mock)
     * @return A unique handle for the encrypted value
     */
    function trivialEncrypt(uint256 value, TEEType teeType) external returns (bytes32) {
        return bytes32(vm.randomUint());
    }

    /**
     * @dev Helper function to grant transient access and then persistent access in the same transaction.
     * This is useful for testing to demonstrate that persistent permissions survive while transient do not.
     * @param handleTransient Handle for which to grant only transient access
     * @param handlePersistent Handle for which to grant persistent access
     * @param account Account to receive both transient and persistent access
     */
    function grantTransientAndPersistent(
        bytes32 handleTransient,
        bytes32 handlePersistent,
        address account
    ) external {
        // Grant transient access (will be cleared after transaction)
        acl.allowTransient(handleTransient, account);

        // Grant transient access to THIS CONTRACT so it can call allow()
        acl.allowTransient(handlePersistent, address(this));

        // Convert to persistent access (will survive after transaction)
        acl.allow(handlePersistent, account);
    }
}
