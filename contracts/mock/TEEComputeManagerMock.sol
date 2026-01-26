// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ACL} from "../../contracts/ACL.sol";

/**
 * @title TEEComputeManagerMock
 * @dev Mock TEEComputeManager contract for testing ACL functionality with helper functions
 * This contract acts as a mock TEE Compute Manager to test ACL permissions
 */
contract TEEComputeManagerMock is TEEComputeManager {
    constructor() {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        // Deploy ACL as a proxy
        address implementation = address(new ACL());
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address, address)",
            address(this),
            address(this)
        );
        $.acl = ACL(address(new ERC1967Proxy(implementation, initData)));
        // Initialize with this contract as owner and teeComputeManager
        // (bool success, ) = address($.acl).call(
        //     abi.encodeWithSignature("initialize(address, address)", address(this), address(this))
        // );
        // require(success, "ACL initialization failed");
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
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        // Grant transient access (will be cleared after transaction)
        $.acl.allowTransient(handleTransient, account);
        // Grant transient access to THIS CONTRACT so it can call allow()
        $.acl.allowTransient(handlePersistent, address(this));
        // Convert to persistent access (will survive after transaction)
        $.acl.allow(handlePersistent, account);
    }
}
