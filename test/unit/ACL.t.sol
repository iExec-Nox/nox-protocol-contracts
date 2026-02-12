// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ACL} from "../../contracts/ACL.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {IACL} from "../../contracts/interfaces/IACL.sol";
import {IErrors} from "../../contracts/interfaces/IErrors.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract ACLTest is Test {
    address internal owner = address(this);
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal viewer1 = makeAddr("viewer1");
    address internal viewer2 = makeAddr("viewer2");
    bytes32 internal handle = keccak256("handle1");
    bytes32 internal handle2 = keccak256("handle2");
    bytes32 internal handle3 = keccak256("handle3");
    ACL internal acl;
    address internal noxCompute;

    function setUp() public {
        NoxCompute noxComputeContract;
        (acl, noxComputeContract) = TestHelper.deploy(owner, makeAddr("gateway"));
        noxCompute = address(noxComputeContract);
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(viewer1, "Viewer1");
        vm.label(viewer2, "Viewer2");
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertEq(acl.owner(), owner);
    }

    function test_RevertWhen_Initialize_Twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        acl.initialize(owner);
    }

    // ============ setNoxCompute ============

    function test_SetNoxCompute() public {
        address newNoxCompute = makeAddr("newNoxCompute");
        vm.prank(owner);
        vm.expectEmit();
        emit IACL.NoxComputeUpdated(newNoxCompute);
        acl.setNoxCompute(newNoxCompute);

        // Verify the new NoxCompute can grant transient access
        vm.prank(newNoxCompute);
        acl.allowTransient(handle, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_RevertWhen_SetNoxCompute_UnauthorizedAccount() public {
        address unauthorized = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized)
        );
        vm.prank(unauthorized);
        acl.setNoxCompute(makeAddr("newNoxCompute"));
    }

    function test_RevertWhen_SetNoxCompute_ZeroAddress() public {
        vm.expectRevert(IErrors.InvalidZeroAddress.selector);
        vm.prank(owner);
        acl.setNoxCompute(address(0));
    }

    // ============ allowPublicDecryption ============

    function test_AllowPublicDecryption_SucceedsWhenCalledByAdmin() public {
        // Setup: grant user1 admin access to handle
        _allow(handle, user1);

        // Mark handle as publicly decryptable
        vm.prank(user1);
        vm.expectEmit();
        emit IACL.MarkedAsPubliclyDecryptable(user1, handle);
        acl.allowPublicDecryption(handle);

        // Verify handle is marked as publicly decryptable
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_SucceedsWhenUserHasTransientAccess() public {
        // Setup: grant user1 transient access to handle
        vm.prank(noxCompute);
        acl.allowTransient(handle, user1);

        // Mark handle as publicly decryptable (in same transaction)
        vm.prank(user1);
        vm.expectEmit();
        emit IACL.MarkedAsPubliclyDecryptable(user1, handle);
        acl.allowPublicDecryption(handle);

        // Verify handle is marked as publicly decryptable
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allowPublicDecryption(handle);
    }

    // ============ isPubliclyDecryptable ============

    function test_IsPubliclyDecryptable_ReturnsFalseByDefault() public view {
        assertFalse(acl.isPubliclyDecryptable(handle));
    }

    // ============ allow ============

    function test_Allow_SucceedsAfterTransientAccess() public {
        // NoxCompute grants transient access to user1
        vm.prank(noxCompute);
        acl.allowTransient(handle, user1);

        // user1 can now grant permanent access to user2 (in same transaction due to transient)
        vm.prank(user1);
        acl.allow(handle, user2);

        // user2 should have permanent access (persists across transactions)
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_AdminCanGrantAccessToNewAdmin() public {
        // Setup: grant user1 admin access
        _allow(handle, user1);

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

    function test_Allow_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allow(handle, user2);
    }

    function test_Allow_RevertWhen_InvalidZeroAddress() public {
        // First grant access to user1
        vm.prank(noxCompute);
        acl.allowTransient(handle, user1);

        // Try to grant to zero address
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidZeroAddress.selector));
        acl.allow(handle, address(0));
    }

    function test_Allow_RevertWhen_CalledByViewer() public {
        // Setup: user1 is admin and adds viewer
        _allow(handle, user1);

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

    // ============ addViewer ============

    function test_AddViewer_SucceedsWhenCalledByAdmin() public {
        // Setup: grant user1 admin access
        _allow(handle, user1);

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

    function test_AddViewer_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.addViewer(handle, user2);
    }

    function test_AddViewer_RevertWhen_InvalidZeroAddress() public {
        // First grant access to user1
        vm.prank(noxCompute);
        acl.allowTransient(handle, user1);

        // Try to add zero address as viewer
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidZeroAddress.selector));
        acl.addViewer(handle, address(0));
    }

    function test_AddViewer_RevertWhen_CalledByViewer() public {
        // Setup: user1 is admin and adds viewer1
        _allow(handle, user1);

        vm.prank(user1);
        acl.addViewer(handle, viewer1);

        // Verify viewer1 is a viewer
        assertTrue(acl.isViewer(handle, viewer1));

        // viewer1 should NOT be able to add another viewer
        vm.prank(viewer1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, viewer1));
        acl.addViewer(handle, viewer2);
    }

    // ============ allowTransient ============

    function test_AllowTransient_SucceedsWhenCalledByNoxCompute() public {
        vm.prank(noxCompute);
        acl.allowTransient(handle, user1);

        // Transient access should be available in the same transaction
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_RevertWhen_UnauthorizedSender() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IACL.UnauthorizedSender.selector, user1));
        acl.allowTransient(handle, user2);
    }

    // ============ cleanTransientStorage ============

    function test_CleanTransientStorage_ClearsMultipleTransientPermissions() public {
        // Simulate a userOp context where NoxCompute grants multiple transient permissions
        vm.startPrank(noxCompute);
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

    function test_CleanTransientStorage_PreservesPersistentPermissions() public {
        // Grant persistent permission to user1 for handle
        _allow(handle, user1);

        // Grant multiple transient permissions in a userOp context
        vm.startPrank(noxCompute);
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

    // ============ isViewer ============

    function test_IsViewer_ReturnsFalseByDefault() public view {
        assertFalse(acl.isViewer(handle, user1));
    }

    function test_IsViewer_ByAnyoneWhenPubliclyDecryptable() public {
        address anyone = makeAddr("anyon");
        assertFalse(acl.isViewer(handle, anyone));

        _allow(handle, owner);

        vm.prank(owner);
        acl.allowPublicDecryption(handle);

        assertTrue(acl.isViewer(handle, anyone));
    }

    function test_IsViewer_WhenAllowed() public {
        assertFalse(acl.isViewer(handle, user1));
        _allow(handle, user1);
        assertTrue(acl.isViewer(handle, user1));
    }

    // ============ isAllowed ============

    function test_IsAllowed_ReturnsFalseByDefault() public view {
        assertFalse(acl.isAllowed(handle, user1));
        assertFalse(acl.isAllowed(handle, user2));
    }

    // ============ validateAllowedForAll ============

    function test_ValidateAllowedForAll() public {
        // Grant access to user1 for multiple handles
        _allow(handle, user1);
        _allow(handle2, user1);
        _allow(handle3, user1);

        // Should not revert when all handles are allowed
        bytes32[] memory handles = new bytes32[](3);
        handles[0] = handle;
        handles[1] = handle2;
        handles[2] = handle3;
        acl.validateAllowedForAll(user1, handles);
    }

    function test_ValidateAllowedForAll_EmptyArray() public view {
        // Should not revert with empty array
        bytes32[] memory handles = new bytes32[](0);
        acl.validateAllowedForAll(user1, handles);
    }

    function test_ValidateAllowedForAll_SingleHandle() public {
        _allow(handle, user1);

        bytes32[] memory handles = new bytes32[](1);
        handles[0] = handle;
        acl.validateAllowedForAll(user1, handles);
    }

    function test_ValidateAllowedForAll_WithTransientAccess() public {
        // Grant transient access
        vm.prank(noxCompute);
        acl.allowTransient(handle, user1);
        vm.prank(noxCompute);
        acl.allowTransient(handle2, user1);

        bytes32[] memory handles = new bytes32[](2);
        handles[0] = handle;
        handles[1] = handle2;
        acl.validateAllowedForAll(user1, handles);
    }

    function test_RevertWhen_ValidateAllowedForAll_FirstHandleNotAllowed() public {
        // Only grant access to handle2 and handle3, not handle
        _allow(handle2, user1);
        _allow(handle3, user1);

        bytes32[] memory handles = new bytes32[](3);
        handles[0] = handle;
        handles[1] = handle2;
        handles[2] = handle3;

        vm.expectRevert(abi.encodeWithSelector(IACL.NotAllowed.selector, handle, user1));
        acl.validateAllowedForAll(user1, handles);
    }

    function test_RevertWhen_ValidateAllowedForAll_NoneAllowed() public {
        bytes32[] memory handles = new bytes32[](2);
        handles[0] = handle;
        handles[1] = handle2;

        // Should revert on the first handle
        vm.expectRevert(abi.encodeWithSelector(IACL.NotAllowed.selector, handle, user1));
        acl.validateAllowedForAll(user1, handles);
    }

    // ============ _authorizeUpgrade ============

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new ACL());
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        acl.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_AuthorizeUpgrade_WithUnauthorizedAccount() public {
        address unauthorized = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized)
        );
        vm.prank(unauthorized);
        acl.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Test Helpers ============

    function _allow(bytes32 h, address account) internal {
        vm.prank(noxCompute);
        acl.allowTransient(h, account);
        vm.prank(account);
        acl.allow(h, account);
    }
}
