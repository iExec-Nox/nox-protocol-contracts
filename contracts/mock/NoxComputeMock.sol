// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {NoxCompute} from "../../contracts/NoxCompute.sol";

/**
 * @title NoxComputeMock
 * @dev Mock NoxCompute contract for testing ACL functionality with helper functions
 */
contract NoxComputeMock is NoxCompute {
    constructor() NoxCompute(0) {}

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
        // Use `this` to make an external call to allowTransient and allow
        // because they are external.
        // Grant transient access (will be cleared after transaction)
        this.allowTransient(handleTransient, account);
        // Grant transient access to THIS CONTRACT so it can call allow()
        this.allowTransient(handlePersistent, address(this));
        // Convert to persistent access (will survive after transaction)
        this.allow(handlePersistent, account);
    }
}
