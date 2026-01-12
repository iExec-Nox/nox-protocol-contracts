// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

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
     * @dev Tests that isAllowed returns false for any address and handle by default.
     */
    function test_IsAllowed_ReturnsFalseByDefault() public view {
        bytes32 handle = keccak256("test-handle");
        assertFalse(acl.isAllowed(handle, user1));
        assertFalse(acl.isAllowed(handle, user2));
    }

    /**
     * @dev Tests that allow() reverts when sender has no access to the handle.
     */
    function test_Allow_RevertWhen_UnauthorizedSender() public {
        bytes32 handle = keccak256("test-handle");
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
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
     *      allowTransient() without having prior access to that handle.
     */
    function test_AllowTransient_SucceedsWhenCalledByTEEComputeManager() public {
        bytes32 handle = keccak256("test-handle");

        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // Transient access should be available in the same transaction
        assertTrue(acl.isAllowed(handle, user1));
    }

    /**
     * @dev Tests that a Non-TEEComputeManager cannot grant transient without access.
     */
    function test_AllowTransient_RevertWhen_UnauthorizedSender() public {
        bytes32 handle = keccak256("test-handle");

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allowTransient(handle, user2);
    }

    /**
     * @dev Tests that the TEEComputeManager grants transient access, then user grants permanent access.
     */
    function test_Allow_SucceedsAfterTransientAccess() public {
        bytes32 handle = keccak256("test-handle");

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
        bytes32 handle = keccak256("test-handle");

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
     * @dev Tests that isViewer returns false by default.
     */
    function test_IsViewer_ReturnsFalseByDefault() public view {
        bytes32 handle = keccak256("test-handle");
        assertFalse(acl.isViewer(handle, user1));
        assertFalse(acl.isViewer(handle, user2));
    }

    /**
     * @dev Tests that addViewer() reverts when sender has no access to the handle.
     */
    function test_AddViewer_RevertWhen_UnauthorizedSender() public {
        bytes32 handle = keccak256("test-handle");

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.addViewer(handle, user2);
    }

    /**
     * @dev Tests that addViewer() reverts with zero address.
     */
    function test_AddViewer_RevertWhen_InvalidZeroAddress() public {
        bytes32 handle = keccak256("test-handle");

        // First grant access to user1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // Try to add zero address as viewer
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.InvalidZeroAddress.selector));
        acl.addViewer(handle, address(0));
    }

    /**
     * @dev Tests that an admin can add a viewer successfully.
     */
    function test_AddViewer_SucceedsWhenCalledByAdmin() public {
        bytes32 handle = keccak256("test-handle");
        address viewer = makeAddr("viewer");

        // Setup: grant user1 admin access
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        // Viewer should not be a viewer yet
        assertFalse(acl.isViewer(handle, viewer));

        // Admin adds viewer
        vm.prank(user1);
        vm.expectEmit(true, true, true, false);
        emit IACL.ViewerAdded(user1, viewer, handle);
        acl.addViewer(handle, viewer);

        // Viewer should now be a viewer
        assertTrue(acl.isViewer(handle, viewer));
    }

    /**
     * @dev Tests that a viewer cannot add another viewer.
     */
    function test_AddViewer_RevertWhen_CalledByViewer() public {
        bytes32 handle = keccak256("test-handle");
        address viewer1 = makeAddr("viewer1");
        address viewer2 = makeAddr("viewer2");

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

    /**
     * @dev Tests that being a viewer does not grant admin privileges.
     */
    function test_Allow_RevertWhen_CalledByViewer() public {
        bytes32 handle = keccak256("test-handle");
        address viewer = makeAddr("viewer");

        // Setup: user1 is admin and adds viewer
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        vm.prank(user1);
        acl.allow(handle, user1);

        vm.prank(user1);
        acl.addViewer(handle, viewer);

        // Verify viewer is a viewer
        assertTrue(acl.isViewer(handle, viewer));

        // Viewer should NOT have admin privileges (cannot call allow)
        vm.prank(viewer);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, viewer));
        acl.allow(handle, user2);

        // Verify viewer is NOT allowed (admin check)
        assertFalse(acl.isAllowed(handle, viewer));
    }

    /**
     * @dev Tests that cleanTransientStorage clears all transient permissions.
     * This is critical for Account Abstraction bundler integration.
     */
    function test_CleanTransientStorage_ClearsAllTransientPermissions() public {
        bytes32 handle1 = keccak256("test-handle-1");
        bytes32 handle2 = keccak256("test-handle-2");

        // TEEComputeManager grants transient access to multiple users
        vm.startPrank(teeComputeManager);
        acl.allowTransient(handle1, user1);
        acl.allowTransient(handle2, user2);
        vm.stopPrank();

        // Verify both have transient access
        assertTrue(acl.isAllowed(handle1, user1));
        assertTrue(acl.isAllowed(handle2, user2));

        // Clean transient storage
        acl.cleanTransientStorage();

        // Verify all transient permissions are cleared
        assertFalse(acl.isAllowed(handle1, user1));
        assertFalse(acl.isAllowed(handle2, user2));
    }

    /**
     * @dev Tests that cleanTransientStorage does not affect persistent permissions.
     */
    function test_CleanTransientStorage_DoesNotAffectPersistentPermissions() public {
        bytes32 handle = keccak256("test-handle");

        // Grant transient access to user1
        vm.prank(teeComputeManager);
        acl.allowTransient(handle, user1);

        // user1 converts it to persistent for themselves and grants persistent to user2
        vm.startPrank(user1);
        acl.allow(handle, user1);
        vm.stopPrank();

        // Verify user1 have persistent access
        assertTrue(acl.isAllowed(handle, user1));

        // Clean transient storage
        acl.cleanTransientStorage();

        // Verify persistent permissions remain
        assertTrue(acl.isAllowed(handle, user1));
    }

    /**
     * @dev Tests cleanTransientStorage in a complex Account Abstraction scenario.
     * Multiple UserOps in a bundle need clean transient state between operations.
     */
    function test_CleanTransientStorage_AccountAbstractionScenario() public {
        bytes32 handle1 = keccak256("userOp1-handle");
        bytes32 handle2 = keccak256("userOp2-handle");
        address bundler = makeAddr("bundler");

        // Simulate UserOp 1: TEEComputeManager grants transient access
        vm.prank(teeComputeManager);
        acl.allowTransient(handle1, user1);

        assertTrue(acl.isAllowed(handle1, user1));

        // Bundler cleans transient storage between UserOps (critical for AA)
        vm.prank(bundler);
        acl.cleanTransientStorage();

        // UserOp 1's transient access should be cleared
        assertFalse(acl.isAllowed(handle1, user1));

        // Simulate UserOp 2: Fresh transient access for different handle
        vm.prank(teeComputeManager);
        acl.allowTransient(handle2, user2);

        assertTrue(acl.isAllowed(handle2, user2));
        // Previous handle should still not have access
        assertFalse(acl.isAllowed(handle1, user1));
    }
}
