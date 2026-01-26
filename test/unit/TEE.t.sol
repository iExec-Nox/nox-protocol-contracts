// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TEEPrimitives} from "../../contracts/lib/TEEPrimitives.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ACL} from "../../contracts/ACL.sol";
import "encrypted-types/EncryptedTypes.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract TEELibTest is Test {
    using TEEPrimitives for *;

    TEEComputeManager internal teeComputeManager;
    ACL internal acl;
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal owner = makeAddr("owner");
    address internal gateway = makeAddr("gateway");

    function setUp() public {
        (acl, teeComputeManager) = TestHelper.deploy(owner, gateway);
        vm.label(user1, "User1");
        vm.label(user2, "User2");

        // Configure TEE storage
        TEEPrimitives.TEEConfig memory config = TEEPrimitives.TEEConfig({
            teeComputeManager: address(teeComputeManager),
            acl: address(acl)
        });
        TEEPrimitives.setTEEStorage(config);
    }

    // ============ Trivial Encryption Tests ============

    function test_ToEbool_SucceedsAndReturnsHandle() public {
        ebool encrypted = TEEPrimitives.toEbool(true);
        assertTrue(ebool.unwrap(encrypted) != 0);
    }

    function test_ToEbool_False_SucceedsAndReturnsHandle() public {
        ebool encrypted = TEEPrimitives.toEbool(false);
        assertTrue(ebool.unwrap(encrypted) != 0);
    }

    function test_ToEaddress_SucceedsAndReturnsHandle() public {
        eaddress encrypted = TEEPrimitives.toEaddress(user1);
        assertTrue(eaddress.unwrap(encrypted) != 0);
    }

    function test_ToEuint256_SucceedsAndReturnsHandle() public {
        euint256 encrypted = TEEPrimitives.toEuint256(12345);
        assertTrue(euint256.unwrap(encrypted) != 0);
    }

    function test_ToEint256_SucceedsAndReturnsHandle() public {
        eint256 encrypted = TEEPrimitives.toEint256(-12345);
        assertTrue(eint256.unwrap(encrypted) != 0);
    }

    // ============ Permission Management - allow ============

    function test_Allow_Ebool_GrantsPermission() public {
        ebool value = TEEPrimitives.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        // TEEComputeManager grants transient access first
        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        // Now allow for user1
        TEEPrimitives.allow(value, user1);

        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_Allow_Eaddress_GrantsPermission() public {
        eaddress value = TEEPrimitives.toEaddress(user1);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allow(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_Euint256_GrantsPermission() public {
        euint256 value = TEEPrimitives.toEuint256(999);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allow(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_Eint256_GrantsPermission() public {
        eint256 value = TEEPrimitives.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allow(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    // ============ Permission Management - allowThis ============

    function test_AllowThis_Ebool_GrantsPermissionToThisContract() public {
        ebool value = TEEPrimitives.toEbool(false);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Euint256_GrantsPermissionToThisContract() public {
        euint256 value = TEEPrimitives.toEuint256(777);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Eint256_GrantsPermissionToThisContract() public {
        eint256 value = TEEPrimitives.toEint256(-777);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Eaddress_GrantsPermissionToThisContract() public {
        eaddress value = TEEPrimitives.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    // ============ Permission Management - allowTransient ============

    function test_AllowTransient_Ebool_GrantsTransientPermission() public {
        ebool value = TEEPrimitives.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_Eaddress_GrantsTransientPermission() public {
        eaddress value = TEEPrimitives.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_Euint256_GrantsTransientPermission() public {
        euint256 value = TEEPrimitives.toEuint256(555);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowTransient(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_AllowTransient_Eint256_GrantsTransientPermission() public {
        eint256 value = TEEPrimitives.toEint256(-555);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    // ============ Public Decryption ============

    function test_AllowPublicDecryption_Ebool_MarksAsPubliclyDecryptable() public {
        ebool value = TEEPrimitives.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_Eaddress_MarksAsPubliclyDecryptable() public {
        eaddress value = TEEPrimitives.toEaddress(user1);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_Euint256_MarksAsPubliclyDecryptable() public {
        euint256 value = TEEPrimitives.toEuint256(12345);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }

    function test_AllowPublicDecryption_Eint256_MarksAsPubliclyDecryptable() public {
        eint256 value = TEEPrimitives.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEEPrimitives.allowPublicDecryption(value);
        assertTrue(acl.isPubliclyDecryptable(handle));
    }
}
