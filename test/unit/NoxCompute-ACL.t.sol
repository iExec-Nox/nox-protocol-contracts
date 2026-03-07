// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TEEType} from "../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxComputeACLTest is Test {
    address internal owner = address(this);
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal viewer1 = makeAddr("viewer1");
    address internal viewer2 = makeAddr("viewer2");
    bytes32 internal handle;
    bytes32 internal handle2;
    bytes32 internal handle3;
    NoxCompute internal noxCompute;

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, makeAddr("gateway"));
        // Use properly formatted handles (isPublicScalar=0, isUniqHandle=1)
        handle = TestHelper.createHandle(TEEType.Uint256);
        handle2 = TestHelper.createHandle(TEEType.Uint256);
        handle3 = TestHelper.createHandle(TEEType.Uint256);
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(viewer1, "Viewer1");
        vm.label(viewer2, "Viewer2");
    }

    // ============ allowPublicDecryption ============

    function test_AllowPublicDecryption_SucceedsWhenCalledByAdmin() public {
        // Setup: grant user1 admin access to handle
        TestHelper.forceAllowPersistent(handle, user1);

        // Mark handle as publicly decryptable
        vm.prank(user1);
        vm.expectEmit();
        emit INoxCompute.MarkedAsPubliclyDecryptable(user1, handle);
        noxCompute.allowPublicDecryption(handle);

        // Verify handle is marked as publicly decryptable
        assertTrue(noxCompute.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_SucceedsWhenUserHasTransientAccess() public {
        // Setup: grant user1 transient access to handle
        TestHelper.forceAllowTransient(handle, user1);

        // Mark handle as publicly decryptable (in same transaction)
        vm.prank(user1);
        vm.expectEmit();
        emit INoxCompute.MarkedAsPubliclyDecryptable(user1, handle);
        noxCompute.allowPublicDecryption(handle);

        // Verify handle is marked as publicly decryptable
        assertTrue(noxCompute.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, user1));
        noxCompute.allowPublicDecryption(handle);
    }

    // ============ isPubliclyDecryptable ============

    function test_IsPubliclyDecryptable_ReturnsFalseByDefault() public view {
        assertFalse(noxCompute.isPubliclyDecryptable(handle));
    }

    // ============ allow ============

    function test_Allow_SucceedsAfterTransientAccess() public {
        // NoxCompute grants transient access to user1
        TestHelper.forceAllowTransient(handle, user1);

        // user1 can now grant permanent access to user2 (in same transaction due to transient)
        vm.prank(user1);
        noxCompute.allow(handle, user2);

        // user2 should have permanent access (persists across transactions)
        assertTrue(noxCompute.isAllowed(handle, user2));
    }

    function test_Allow_AdminCanGrantAccessToNewAdmin() public {
        // Setup: grant user1 admin access
        TestHelper.forceAllowPersistent(handle, user1);

        // Verify user1 has permanent access
        assertTrue(noxCompute.isAllowed(handle, user1));

        // user2 should not have access yet
        assertFalse(noxCompute.isAllowed(handle, user2));

        // user1 can grant access to user2
        vm.prank(user1);
        noxCompute.allow(handle, user2);

        // Both admins should have permanent access
        assertTrue(noxCompute.isAllowed(handle, user1));
        assertTrue(noxCompute.isAllowed(handle, user2));
    }

    function test_Allow_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, user1));
        noxCompute.allow(handle, user2);
    }

    function test_Allow_RevertWhen_InvalidZeroAddress() public {
        // First grant access to user1
        TestHelper.forceAllowTransient(handle, user1);

        // Try to grant to zero address
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.InvalidZeroAddress.selector));
        noxCompute.allow(handle, address(0));
    }

    function test_Allow_RevertWhen_CalledByViewer() public {
        // Setup: user1 is admin and adds viewer
        TestHelper.forceAllowPersistent(handle, user1);

        vm.prank(user1);
        noxCompute.addViewer(handle, viewer1);

        // Verify viewer is a viewer
        assertTrue(noxCompute.isViewer(handle, viewer1));

        // Viewer should NOT have admin privileges (cannot call allow)
        vm.prank(viewer1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, viewer1));
        noxCompute.allow(handle, user2);

        // Verify viewer is NOT allowed (admin check)
        assertFalse(noxCompute.isAllowed(handle, viewer1));
    }

    // ============ addViewer ============

    function test_AddViewer_SucceedsWhenCalledByAdmin() public {
        // Setup: grant user1 admin access
        TestHelper.forceAllowPersistent(handle, user1);

        // Viewer should not be a viewer yet
        assertFalse(noxCompute.isViewer(handle, viewer1));

        // Admin adds viewer
        vm.prank(user1);
        vm.expectEmit();
        emit INoxCompute.ViewerAdded(user1, viewer1, handle);
        noxCompute.addViewer(handle, viewer1);

        // Viewer should now be a viewer
        assertTrue(noxCompute.isViewer(handle, viewer1));
    }

    function test_AddViewer_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, user1));
        noxCompute.addViewer(handle, user2);
    }

    function test_AddViewer_RevertWhen_InvalidZeroAddress() public {
        // First grant access to user1
        TestHelper.forceAllowTransient(handle, user1);

        // Try to add zero address as viewer
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.InvalidZeroAddress.selector));
        noxCompute.addViewer(handle, address(0));
    }

    function test_AddViewer_RevertWhen_CalledByViewer() public {
        // Setup: user1 is admin and adds viewer1
        TestHelper.forceAllowPersistent(handle, user1);

        vm.prank(user1);
        noxCompute.addViewer(handle, viewer1);

        // Verify viewer1 is a viewer
        assertTrue(noxCompute.isViewer(handle, viewer1));

        // viewer1 should NOT be able to add another viewer
        vm.prank(viewer1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, viewer1));
        noxCompute.addViewer(handle, viewer2);
    }

    // ============ allowTransient ============

    function test_AllowTransient_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, user1));
        noxCompute.allowTransient(handle, user2);
    }

    // ============ cleanTransientStorage ============

    function test_CleanTransientStorage_ClearsMultipleTransientPermissions() public {
        // Simulate a userOp context where NoxCompute grants multiple transient permissions
        TestHelper.forceAllowTransient(handle, user1);
        TestHelper.forceAllowTransient(handle2, user2);

        // Verify all transient permissions are active
        assertTrue(noxCompute.isAllowed(handle, user1));
        assertTrue(noxCompute.isAllowed(handle2, user2));

        // Clean transient storage (simulating end of userOp)
        noxCompute.cleanTransientStorage();

        // Verify all transient permissions are cleared
        assertFalse(noxCompute.isAllowed(handle, user1));
        assertFalse(noxCompute.isAllowed(handle2, user2));
    }

    function test_CleanTransientStorage_PreservesPersistentPermissions() public {
        // Grant persistent permission to user1 for handle
        TestHelper.forceAllowPersistent(handle, user1);

        // Grant multiple transient permissions in a userOp context
        TestHelper.forceAllowTransient(handle2, user2);

        // Verify all permissions are active
        assertTrue(noxCompute.isAllowed(handle, user1)); // persistent
        assertTrue(noxCompute.isAllowed(handle2, user2)); // transient

        // Clean transient storage (simulating end of userOp)
        noxCompute.cleanTransientStorage();

        // Verify persistent permission remains while transient are cleared
        assertTrue(noxCompute.isAllowed(handle, user1)); // persistent - still there
        assertFalse(noxCompute.isAllowed(handle2, user2)); // transient - cleared
    }

    // ============ isViewer ============

    function test_IsViewer_ReturnsFalseByDefault() public view {
        assertFalse(noxCompute.isViewer(handle, user1));
    }

    function test_IsViewer_ByAnyoneWhenPubliclyDecryptable() public {
        address anyone = makeAddr("anyone");
        assertFalse(noxCompute.isViewer(handle, anyone));

        TestHelper.forceAllowPersistent(handle, owner);

        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);

        assertTrue(noxCompute.isViewer(handle, anyone));
    }

    function test_IsViewer_WhenAllowed() public {
        assertFalse(noxCompute.isViewer(handle, user1));
        TestHelper.forceAllowPersistent(handle, user1);
        assertTrue(noxCompute.isViewer(handle, user1));
    }

    // ============ isAllowed ============

    function test_IsAllowed_ReturnsFalseByDefault() public view {
        assertFalse(noxCompute.isAllowed(handle, user1));
    }

    // ============ validateAllowedForAll ============

    function test_ValidateAllowedForAll() public {
        // Grant access to user1 for multiple handles
        TestHelper.forceAllowPersistent(handle, user1);
        TestHelper.forceAllowPersistent(handle2, user1);
        TestHelper.forceAllowPersistent(handle3, user1);

        // Should not revert when all handles are allowed
        bytes32[] memory handles = new bytes32[](3);
        handles[0] = handle;
        handles[1] = handle2;
        handles[2] = handle3;
        noxCompute.validateAllowedForAll(user1, handles);
    }

    function test_ValidateAllowedForAll_EmptyArray() public view {
        // Should not revert with empty array
        bytes32[] memory handles = new bytes32[](0);
        noxCompute.validateAllowedForAll(user1, handles);
    }

    function test_ValidateAllowedForAll_SingleHandle() public {
        TestHelper.forceAllowPersistent(handle, user1);

        bytes32[] memory handles = new bytes32[](1);
        handles[0] = handle;
        noxCompute.validateAllowedForAll(user1, handles);
    }

    function test_ValidateAllowedForAll_WithTransientAccess() public {
        // Grant transient access
        TestHelper.forceAllowTransient(handle, user1);
        TestHelper.forceAllowTransient(handle2, user1);

        bytes32[] memory handles = new bytes32[](2);
        handles[0] = handle;
        handles[1] = handle2;
        noxCompute.validateAllowedForAll(user1, handles);
    }

    function test_RevertWhen_ValidateAllowedForAll_FirstHandleNotAllowed() public {
        // Only grant access to handle2 and handle3, not handle
        TestHelper.forceAllowPersistent(handle2, user1);
        TestHelper.forceAllowPersistent(handle3, user1);

        bytes32[] memory handles = new bytes32[](3);
        handles[0] = handle;
        handles[1] = handle2;
        handles[2] = handle3;

        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, handle, user1));
        noxCompute.validateAllowedForAll(user1, handles);
    }

    function test_RevertWhen_ValidateAllowedForAll_NoneAllowed() public {
        bytes32[] memory handles = new bytes32[](2);
        handles[0] = handle;
        handles[1] = handle2;

        // Should revert on the first handle
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, handle, user1));
        noxCompute.validateAllowedForAll(user1, handles);
    }
}
