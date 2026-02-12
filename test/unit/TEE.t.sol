// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {ACL} from "../../contracts/ACL.sol";
import "encrypted-types/EncryptedTypes.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract TEELibTest is Test {
    NoxCompute internal noxCompute;
    ACL internal acl;
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal owner = makeAddr("owner");
    address internal gateway = makeAddr("gateway");

    function setUp() public {
        (acl, noxCompute) = TestHelper.deploy(owner, gateway);
        vm.label(user1, "User1");
        vm.label(user2, "User2");
    }

    // ============ Trivial Encryption ============

    function test_ToEbool_SucceedsAndReturnsHandle() public {
        ebool encrypted = Nox.toEbool(true);
        assertTrue(ebool.unwrap(encrypted) != 0);
    }

    function test_ToEbool_False_SucceedsAndReturnsHandle() public {
        ebool encrypted = Nox.toEbool(false);
        assertTrue(ebool.unwrap(encrypted) != 0);
    }

    function test_ToEaddress_SucceedsAndReturnsHandle() public {
        eaddress encrypted = Nox.toEaddress(user1);
        assertTrue(eaddress.unwrap(encrypted) != 0);
    }

    function test_ToEuint256_SucceedsAndReturnsHandle() public {
        euint256 encrypted = Nox.toEuint256(12345);
        assertTrue(euint256.unwrap(encrypted) != 0);
    }

    function test_ToEint256_SucceedsAndReturnsHandle() public {
        eint256 encrypted = Nox.toEint256(-12345);
        assertTrue(eint256.unwrap(encrypted) != 0);
    }

    // ============ Permission Management - allow ============

    function test_Allow_Ebool_GrantsPermission() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        // NoxCompute grants transient access first
        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        // Now allow for user1
        Nox.allow(value, user1);

        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_Allow_Eaddress_GrantsPermission() public {
        eaddress value = Nox.toEaddress(user1);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_Euint256_GrantsPermission() public {
        euint256 value = Nox.toEuint256(999);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_Eint256_GrantsPermission() public {
        eint256 value = Nox.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    // ============ Permission Management - allowThis ============

    function test_AllowThis_Ebool_GrantsPermissionToThisContract() public {
        ebool value = Nox.toEbool(false);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Euint256_GrantsPermissionToThisContract() public {
        euint256 value = Nox.toEuint256(777);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Eint256_GrantsPermissionToThisContract() public {
        eint256 value = Nox.toEint256(-777);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Eaddress_GrantsPermissionToThisContract() public {
        eaddress value = Nox.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    // ============ Permission Management - allowTransient ============

    function test_AllowTransient_Ebool_GrantsTransientPermission() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_Eaddress_GrantsTransientPermission() public {
        eaddress value = Nox.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_Euint256_GrantsTransientPermission() public {
        euint256 value = Nox.toEuint256(555);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowTransient(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_AllowTransient_Eint256_GrantsTransientPermission() public {
        eint256 value = Nox.toEint256(-555);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    // ============ Viewer Management - addViewer ============

    function test_AddViewer_Ebool_AddsViewer() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(acl.isViewer(handle, user1));
    }

    function test_AddViewer_Eaddress_AddsViewer() public {
        eaddress value = Nox.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(acl.isViewer(handle, user1));
    }

    function test_AddViewer_Euint256_AddsViewer() public {
        euint256 value = Nox.toEuint256(12345);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(acl.isViewer(handle, user1));
    }

    function test_AddViewer_Eint256_AddsViewer() public {
        eint256 value = Nox.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(acl.isViewer(handle, user1));
    }

    // ============ Public Decryption ============

    function test_AllowPublicDecryption_Ebool_MarksAsPubliclyDecryptable() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_Eaddress_MarksAsPubliclyDecryptable() public {
        eaddress value = Nox.toEaddress(user1);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_Euint256_MarksAsPubliclyDecryptable() public {
        euint256 value = Nox.toEuint256(12345);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_Eint256_MarksAsPubliclyDecryptable() public {
        eint256 value = Nox.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    // ============ Authorization Queries - isAllowed ============

    function test_IsAllowed_Ebool_ReturnsTrueWhenAllowed() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user1);
        assertTrue(Nox.isAllowed(value, user1));
    }

    function test_IsAllowed_Eaddress_ReturnsTrueWhenAllowed() public {
        eaddress value = Nox.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user1);
        assertTrue(Nox.isAllowed(value, user1));
    }

    function test_IsAllowed_Euint256_ReturnsTrueWhenAllowed() public {
        euint256 value = Nox.toEuint256(12345);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user1);
        assertTrue(Nox.isAllowed(value, user1));
    }

    function test_IsAllowed_Eint256_ReturnsTrueWhenAllowed() public {
        eint256 value = Nox.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allow(value, user1);
        assertTrue(Nox.isAllowed(value, user1));
    }

    // ============ Authorization Queries - isPubliclyDecryptable ============

    function test_IsPubliclyDecryptable_Ebool_ReturnsTrueWhenPublic() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_IsPubliclyDecryptable_Eaddress_ReturnsTrueWhenPublic() public {
        eaddress value = Nox.toEaddress(user1);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_IsPubliclyDecryptable_Euint256_ReturnsTrueWhenPublic() public {
        euint256 value = Nox.toEuint256(12345);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_IsPubliclyDecryptable_Eint256_ReturnsTrueWhenPublic() public {
        eint256 value = Nox.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    // ============ Authorization Queries - isViewer ============

    function test_IsViewer_Ebool_ReturnsTrueWhenViewer() public {
        ebool value = Nox.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(Nox.isViewer(value, user1));
    }

    function test_IsViewer_Eaddress_ReturnsTrueWhenViewer() public {
        eaddress value = Nox.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(Nox.isViewer(value, user1));
    }

    function test_IsViewer_Euint256_ReturnsTrueWhenViewer() public {
        euint256 value = Nox.toEuint256(12345);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(Nox.isViewer(value, user1));
    }

    function test_IsViewer_Eint256_ReturnsTrueWhenViewer() public {
        eint256 value = Nox.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(noxCompute));
        acl.allowTransient(handle, address(this));

        Nox.addViewer(value, user1);
        assertTrue(Nox.isViewer(value, user1));
    }
}
