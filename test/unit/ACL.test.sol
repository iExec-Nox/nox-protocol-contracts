// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ACL} from "../../contracts/ACL.sol";
import {IACL} from "../../contracts/interfaces/IACL.sol";
import {IErrors} from "../../contracts/interfaces/IErrors.sol";

contract ACLTest is Test {
    ACL internal acl;
    address internal teeComputeManager;
    address internal user1;
    address internal user2;
    address internal viewer1;
    address internal viewer2;
    bytes32 internal handle;
    bytes32 internal handle2;
    bytes32 internal handle3;

    function setUp() public {
        teeComputeManager = makeAddr("teeComputeManager");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        viewer1 = makeAddr("viewer1");
        viewer2 = makeAddr("viewer2");
        handle = keccak256("handle-1");
        handle2 = keccak256("handle-2");
        handle3 = keccak256("handle-3");

        vm.label(teeComputeManager, "TEEComputeManager");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(viewer1, "Viewer1");
        vm.label(viewer2, "Viewer2");

        acl = new ACL(teeComputeManager);
        vm.label(address(acl), "ACL");
    }

    // ============ isAllowed ============

    /**
     * @dev Tests that isAllowed returns false for any address and handle by default.
     */
    function test_IsAllowed_ReturnsFalseByDefault() public view {
        assertFalse(acl.isAllowed(handle, user1));
        assertFalse(acl.isAllowed(handle, user2));
    }

    // ============ allowTransient ============

    /**
     * @dev Tests that the TEEComputeManager can grant transient access to a handle via
     *      allowTransient() without having prior access to that handle.
     */
    function test_AllowTransient_SucceedsWhenCalledByTEEComputeManager() public {
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // Transient access should be available in the same transaction
        assertTrue(acl.isAllowed(handle, user1));
    }

    /**
     * @dev Tests that a Non-TEEComputeManager cannot grant transient without access.
     */
    function test_AllowTransient_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allowTransient(handle, user2);
    }

    // ============ allow ============

    /**
     * @dev Tests that the TEEComputeManager grants transient access, then user grants permanent access.
     */
    function test_Allow_SucceedsAfterTransientAccess() public {
        // TEEComputeManager grants transient access to user1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // user1 can now grant permanent access to user2 (in same transaction due to transient)
        vm.prank(user1);
        acl.allow(handle, user2);

        // user2 should have permanent access (persists across transactions)
        assertTrue(acl.isAllowed(handle, user2));
    }

    /**
     * @dev Tests that an admin with permanent access can grant access to a new admin.
     */
    function test_Allow_AdminCanGrantAccessToNewAdmin() public {
        // Setup: TEEComputeManager grants transient access to user1, who converts it to permanent
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        // Verify user1 has permanent access
        assertTrue(acl.isAllowed(handle, user1));

        // user2 should not have access yet
        assertFalse(acl.isAllowed(handle, user2));

        // user1 can grant access to user2
        vm.prank(user1);
        acl.allow(handle, user2);

        // Both admins should have permanent access
        assertTrue(acl.isAllowed(handle, user1));
        assertTrue(acl.isAllowed(handle, user2));
    }

    /**
     * @dev Tests that allow() reverts when sender has no access to the handle.
     */
    function test_Allow_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allow(handle, user2);
    }

    /**
     * @dev Tests that allow() reverts with zero address.
     */
    function test_Allow_RevertWhen_InvalidZeroAddress() public {
        // First grant access to user1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // Try to grant to zero address
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidZeroAddress.selector));
        acl.allow(handle, address(0));
    }

    /**
     * @dev Tests that being a viewer does not grant admin privileges.
     */
    function test_Allow_RevertWhen_CalledByViewer() public {
        // Setup: user1 is admin and adds viewer
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        vm.prank(user1);
        acl.addViewer(handle, viewer1);

        // Verify viewer is a viewer
        assertTrue(acl.isViewer(handle, viewer1));

        // Viewer should NOT have admin privileges (cannot call allow)
        vm.prank(viewer1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, viewer1));
        acl.allow(handle, user2);

        // Verify viewer is NOT allowed (admin check)
        assertFalse(acl.isAllowed(handle, viewer1));
    }

    // ============ isViewer ============

    /**
     * @dev Tests that isViewer returns false by default.
     */
    function test_IsViewer_ReturnsFalseByDefault() public view {
        assertFalse(acl.isViewer(handle, user1));
    }

    // ============ addViewer ============

    /**
     * @dev Tests that an admin can add a viewer successfully.
     */
    function test_AddViewer_SucceedsWhenCalledByAdmin() public {
        // Setup: grant user1 admin access
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        // Viewer should not be a viewer yet
        assertFalse(acl.isViewer(handle, viewer1));

        // Admin adds viewer
        vm.prank(user1);
        vm.expectEmit();
        emit IACL.ViewerAdded(user1, viewer1, handle);
        acl.addViewer(handle, viewer1);

        // Viewer should now be a viewer
        assertTrue(acl.isViewer(handle, viewer1));
    }

    /**
     * @dev Tests that addViewer() reverts when sender has no access to the handle.
     */
    function test_AddViewer_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.addViewer(handle, user2);
    }

    /**
     * @dev Tests that addViewer() reverts with zero address.
     */
    function test_AddViewer_RevertWhen_InvalidZeroAddress() public {
        // First grant access to user1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // Try to add zero address as viewer
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidZeroAddress.selector));
        acl.addViewer(handle, address(0));
    }

    /**
     * @dev Tests that a viewer cannot add another viewer.
     */
    function test_AddViewer_RevertWhen_CalledByViewer() public {
        // Setup: user1 is admin and adds viewer1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        vm.prank(user1);
        acl.addViewer(handle, viewer1);

        // Verify viewer1 is a viewer
        assertTrue(acl.isViewer(handle, viewer1));

        // viewer1 should NOT be able to add another viewer
        vm.prank(viewer1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, viewer1));
        acl.addViewer(handle, viewer2);
    }

    // ============ cleanTransientStorage ============

    /**
     * @dev Tests that cleanTransientStorage properly clears all transient permissions
     *      for multiple handles and accounts in a userOp context.
     */
    function test_CleanTransientStorage_ClearsMultipleTransientPermissions() public {
        // Simulate a userOp context where TEEComputeManager grants multiple transient permissions
        vm.startPrank(teeComputeManager);
        acl.allowTransient(handle, user1);
        acl.allowTransient(handle2, user2);
        vm.stopPrank();

        // Verify all transient permissions are active
        assertTrue(acl.isAllowed(handle, user1));
        assertTrue(acl.isAllowed(handle2, user2));

        // Clean transient storage (simulating end of userOp)
        acl.cleanTransientStorage();

        // Verify all transient permissions are cleared
        assertFalse(acl.isAllowed(handle, user1));
        assertFalse(acl.isAllowed(handle2, user2));
    }

    /**
     * @dev Tests that cleanTransientStorage only clears transient permissions
     *      and does not affect persistent permissions in a userOp context.
     */
    function test_CleanTransientStorage_PreservesPersistentPermissions() public {
        // Grant persistent permission to user1 for handle
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);
        vm.prank(user1);
        acl.allow(handle, user1);

        // Grant multiple transient permissions in a userOp context
        vm.startPrank(teeComputeManager);
        acl.allowTransient(handle2, user2);
        vm.stopPrank();

        // Verify all permissions are active
        assertTrue(acl.isAllowed(handle, user1)); // persistent
        assertTrue(acl.isAllowed(handle2, user2)); // transient

        // Clean transient storage (simulating end of userOp)
        acl.cleanTransientStorage();

        // Verify persistent permission remains while transient are cleared
        assertTrue(acl.isAllowed(handle, user1)); // persistent - still there
        assertFalse(acl.isAllowed(handle2, user2)); // transient - cleared
    }

    // ============ allowPublicDecryption ============

    /**
     * @dev Tests that an admin can mark a handle as publicly decryptable.
     */
    function test_AllowPublicDecryption_SucceedsWhenCalledByAdmin() public {
        // Setup: grant user1 admin access to handle
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        // Mark handle as publicly decryptable
        vm.prank(user1);
        vm.expectEmit();
        emit IACL.MarkedAsPubliclyDecryptable(user1, handle);
        acl.allowPublicDecryption(handle);

        // Verify handle is marked as publicly decryptable
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    /**
     * @dev Tests that a user with transient access can mark a handle as publicly decryptable.
     */
    function test_AllowPublicDecryption_SucceedsWhenUserHasTransientAccess() public {
        // Setup: grant user1 transient access to handle
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // Mark handle as publicly decryptable (in same transaction)
        vm.prank(user1);
        vm.expectEmit();
        emit IACL.MarkedAsPubliclyDecryptable(user1, handle);
        acl.allowPublicDecryption(handle);

        // Verify handle is marked as publicly decryptable
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    /**
     * @dev Tests that allowPublicDecryption() reverts when sender doesn't have access to a handle.
     */
    function test_AllowPublicDecryption_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allowPublicDecryption(handle);
    }

    // ============ isPubliclyDecryptable ============

    /**
     * @dev Tests that isPubliclyDecryptable returns false by default.
     */
    function test_IsPubliclyDecryptable_ReturnsFalseByDefault() public view {
        assertFalse(acl.isPubliclyDecryptable(handle));
    }
}
