// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ACL} from "../../contracts/ACL.sol";
import {IACL} from "../../contracts/interfaces/IACL.sol";

contract ACLTest is Test {
    ACL internal acl;
    address internal teeComputeManager;
    address internal user1;
    address internal user2;

    function setUp() public {
        teeComputeManager = makeAddr("teeComputeManager");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.label(teeComputeManager, "TEEComputeManager");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        
        acl = new ACL(teeComputeManager);
        vm.label(address(acl), "ACL");
    }

    /**
     * @dev Tests that isAllowed returns false for any address and handle by default (fuzz test).
     */
    function testFuzz_IsAllowed_ReturnsFalseByDefault(bytes32 handle, address account) public view {
        assertFalse(acl.isAllowed(handle, account));
    }

    /**
     * @dev Tests that allow() reverts when sender has no access to the handle.
     */
    function testFuzz_Allow_RevertWhen_UnauthorizedSender(bytes32 handle, address account) public {
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, account));
        acl.allow(handle, user2);
    }

    /**
     * @dev Tests that allow() reverts with zero address.
     */
    function test_Allow_RevertWhen_InvalidZeroAddress() public {
        bytes32 handle = keccak256("test-handle");
        
        // First grant access to user1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);
        
        // Try to grant to zero address
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.InvalidZeroAddress.selector));
        acl.allow(handle, address(0));
    }

    /**
     * @dev Tests that the TEEComputeManager can grant transient access to a handle via
     *      allowTransient() without having prior access to that handle (fuzz test).
     */
    function testFuzz_AllowTransient_SucceedsWhenCalledByTEEComputeManager(bytes32 handle, address account) public {
        vm.assume(account != address(0));
        
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, account);
        
        // Transient access should be available in the same transaction
        assertTrue(acl.isAllowed(handle, account));
    }

    /**
     * @dev Tests that a Non-TEEComputeManager cannot grant transient without access.
     */
    function testFuzz_AllowTransient_RevertWhen_UnauthorizedSender(
        address sender,
        bytes32 handle,
        address account
    ) public {
        vm.assume(sender != teeComputeManager);
        vm.assume(account != address(0));
        
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, sender));
        acl.allowTransient(handle, account);
    }

    /**
     * @dev Tests that the TEEComputeManager grants transient access, then user grants permanent access (fuzz test).
     */
    function testFuzz_Allow_SucceedsAfterTransientAccess(bytes32 handle, address user, address target) public {
        vm.assume(user != address(0));
        vm.assume(target != address(0));
        
        // TEEComputeManager grants transient access to user
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user);
        
        // user can now grant permanent access to target (in same transaction due to transient)
        vm.prank(user);
        acl.allow(handle, target);
        
        // target should have permanent access (persists across transactions)
        assertTrue(acl.isAllowed(handle, target));
    }

    /**
     * @dev Tests that an admin with permanent access can grant access to a new admin (fuzz test).
     */
    function testFuzz_Allow_AdminCanGrantAccessToNewAdmin(bytes32 handle, address admin1, address admin2) public {
        vm.assume(admin1 != address(0));
        vm.assume(admin2 != address(0));
        
        // Setup: TEEComputeManager grants transient access to admin1, who converts it to permanent
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, admin1);
        
        vm.prank(admin1);
        acl.allow(handle, admin1);
        
        // Verify admin1 has permanent access
        assertTrue(acl.isAllowed(handle, admin1));
        
        // admin2 should not have access yet
        assertFalse(acl.isAllowed(handle, admin2));
        
        // admin1 can grant access to admin2
        vm.prank(admin1);
        acl.allow(handle, admin2);
        
        // Both admins should have permanent access
        assertTrue(acl.isAllowed(handle, admin1));
        assertTrue(acl.isAllowed(handle, admin2));
    }

    //TODO: Tests that permanent access persists while transient does not after the end of the transaction
}
