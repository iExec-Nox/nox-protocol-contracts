// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TEE} from "../../contracts/lib/TEE.sol";
import {TEEComputeManagerMock} from "../../contracts/mock/TEEComputeManagerMock.sol";
import {ACL} from "../../contracts/ACL.sol";
import "encrypted-types/EncryptedTypes.sol";

contract TEELibTest is Test {
    using TEE for *;

    TEEComputeManagerMock internal teeComputeManager;
    ACL internal acl;
    address internal user1;
    address internal user2;

    function setUp() public {
        teeComputeManager = new TEEComputeManagerMock();
        acl = teeComputeManager.acl();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.label(address(teeComputeManager), "TEEComputeManager");
        vm.label(address(acl), "ACL");
        vm.label(user1, "User1");
        vm.label(user2, "User2");

        // Configure TEE storage
        TEE.TEEConfig memory config = TEE.TEEConfig({
            teeComputeManager: address(teeComputeManager),
            acl: address(acl)
        });
        TEE.setTEEStorage(config);
    }

    // ============ Trivial Encryption Tests ============

    function test_ToEbool_SucceedsAndReturnsHandle() public {
        ebool encrypted = TEE.toEbool(true);
        assertTrue(ebool.unwrap(encrypted) != 0);
    }

    function test_ToEbool_False_SucceedsAndReturnsHandle() public {
        ebool encrypted = TEE.toEbool(false);
        assertTrue(ebool.unwrap(encrypted) != 0);
    }

    function test_ToEaddress_SucceedsAndReturnsHandle() public {
        eaddress encrypted = TEE.toEaddress(user1);
        assertTrue(eaddress.unwrap(encrypted) != 0);
    }

    function test_ToEuint256_SucceedsAndReturnsHandle() public {
        euint256 encrypted = TEE.toEuint256(12345);
        assertTrue(euint256.unwrap(encrypted) != 0);
    }

    function test_ToEint256_SucceedsAndReturnsHandle() public {
        eint256 encrypted = TEE.toEint256(-12345);
        assertTrue(eint256.unwrap(encrypted) != 0);
    }

    // ============ Permission Management - allow ============

    function test_Allow_Ebool_GrantsPermission() public {
        ebool value = TEE.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        // TEEComputeManager grants transient access first
        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        // Now allow for user1
        TEE.allow(value, user1);

        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_Allow_Eaddress_GrantsPermission() public {
        eaddress value = TEE.toEaddress(user1);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allow(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_Euint256_GrantsPermission() public {
        euint256 value = TEE.toEuint256(999);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allow(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_Allow_Eint256_GrantsPermission() public {
        eint256 value = TEE.toEint256(-999);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allow(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    // ============ Permission Management - allowThis ============

    function test_AllowThis_Ebool_GrantsPermissionToThisContract() public {
        ebool value = TEE.toEbool(false);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Euint256_GrantsPermissionToThisContract() public {
        euint256 value = TEE.toEuint256(777);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Eint256_GrantsPermissionToThisContract() public {
        eint256 value = TEE.toEint256(-777);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    function test_AllowThis_Eaddress_GrantsPermissionToThisContract() public {
        eaddress value = TEE.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowThis(value);
        assertTrue(acl.isAllowed(handle, address(this)));
    }

    // ============ Permission Management - allowTransient ============

    function test_AllowTransient_Ebool_GrantsTransientPermission() public {
        ebool value = TEE.toEbool(true);
        bytes32 handle = ebool.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_Eaddress_GrantsTransientPermission() public {
        eaddress value = TEE.toEaddress(user2);
        bytes32 handle = eaddress.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

    function test_AllowTransient_Euint256_GrantsTransientPermission() public {
        euint256 value = TEE.toEuint256(555);
        bytes32 handle = euint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowTransient(value, user2);
        assertTrue(acl.isAllowed(handle, user2));
    }

    function test_AllowTransient_Eint256_GrantsTransientPermission() public {
        eint256 value = TEE.toEint256(-555);
        bytes32 handle = eint256.unwrap(value);

        vm.prank(address(teeComputeManager));
        acl.allowTransient(handle, address(this));

        TEE.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }

        TEE.allowTransient(value, user1);
        assertTrue(acl.isAllowed(handle, user1));
    }
}
