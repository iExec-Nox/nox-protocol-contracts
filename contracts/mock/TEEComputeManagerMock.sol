// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";

/**
 * @title TEEComputeManagerMock
 * @dev Mock TEEComputeManager contract for testing ACL functionality with helper functions
 * This contract acts as a mock TEE Compute Manager to test ACL permissions
 */
contract TEEComputeManagerMock is TEEComputeManager {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address acl_) TEEComputeManager(acl_) {}

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
        _acl.allowTransient(handleTransient, account);
        // Grant transient access to THIS CONTRACT so it can call allow()
        _acl.allowTransient(handlePersistent, address(this));
        // Convert to persistent access (will survive after transaction)
        _acl.allow(handlePersistent, account);
    }
}
