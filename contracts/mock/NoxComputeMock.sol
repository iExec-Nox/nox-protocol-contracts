// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Admin} from "../modules/Admin.sol";
import {ACL} from "../modules/ACL.sol";
import {Compute} from "../modules/Compute.sol";

/**
 * @title NoxComputeMock
 * @dev Mock NoxCompute contract for testing ACL functionality with helper functions
 */
contract NoxComputeMock is Admin, ACL, Compute layout at erc7201("nox.storage.NoxCompute") {
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() EIP712("NoxCompute", "1") {
        _disableInitializers();
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
