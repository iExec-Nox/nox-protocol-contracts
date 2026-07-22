// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxCompute_AdminTest is Test {
    uint256 constant SECP256K1_FIELD_PRIME =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    bytes kmsKey = abi.encodePacked(bytes1(0x02), keccak256("kms-key"));
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    NoxCompute noxCompute;

    function setUp() public {
        noxCompute = TestHelper.deploy(admin, upgrader, gateway, kmsKey);
    }

    // ============ setKmsPublicKey ============

    function test_SetKmsPublicKey() public {
        // 33-byte compressed SEC1 secp256k1 public key
        bytes memory newKey = abi.encodePacked(bytes1(0x02), keccak256("new-kms-key"));
        vm.prank(upgrader);
        vm.expectEmit();
        emit INoxCompute.KmsPublicKeyUpdated(newKey);
        noxCompute.setKmsPublicKey(newKey);
        assertEq(noxCompute.kmsPublicKey(), newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        bytes memory newKey = abi.encodePacked(bytes1(0x02), keccak256("unauthorized-kms-key"));
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.UPGRADER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.setKmsPublicKey(newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_InvalidLength() public {
        // 0 bytes (empty)
        vm.expectRevert(INoxCompute.InvalidKmsPublicKeyLength.selector);
        vm.prank(upgrader);
        noxCompute.setKmsPublicKey(new bytes(0));
        // 32 bytes (too short)
        vm.expectRevert(INoxCompute.InvalidKmsPublicKeyLength.selector);
        vm.prank(upgrader);
        noxCompute.setKmsPublicKey(new bytes(32));
        // 34 bytes (too long)
        vm.expectRevert(INoxCompute.InvalidKmsPublicKeyLength.selector);
        vm.prank(upgrader);
        noxCompute.setKmsPublicKey(new bytes(34));
    }

    function test_RevertWhen_SetKmsPublicKey_InvalidPrefix() public {
        bytes1[3] memory invalidPrefixes = [bytes1(0x00), bytes1(0x01), bytes1(0x04)];
        for (uint256 i = 0; i < invalidPrefixes.length; i++) {
            bytes memory newKey = abi.encodePacked(invalidPrefixes[i], keccak256("kms-key"));
            vm.expectRevert(INoxCompute.InvalidKmsPublicKey.selector);
            vm.prank(upgrader);
            noxCompute.setKmsPublicKey(newKey);
        }
    }

    function test_SetKmsPublicKey_AcceptsBothValidPrefixes() public {
        bytes1[2] memory validPrefixes = [bytes1(0x02), bytes1(0x03)];
        for (uint256 i = 0; i < validPrefixes.length; i++) {
            bytes memory newKey = abi.encodePacked(validPrefixes[i], keccak256("kms-key"));
            vm.prank(upgrader);
            noxCompute.setKmsPublicKey(newKey);
            assertEq(noxCompute.kmsPublicKey(), newKey);
        }
    }

    function test_RevertWhen_SetKmsPublicKey_XCoordinateNotBelowFieldPrime() public {
        // X-coordinate == p (not strictly below the field prime)
        bytes memory keyAtPrime = abi.encodePacked(bytes1(0x02), bytes32(SECP256K1_FIELD_PRIME));
        vm.expectRevert(INoxCompute.InvalidKmsPublicKey.selector);
        vm.prank(upgrader);
        noxCompute.setKmsPublicKey(keyAtPrime);

        // X-coordinate == p + 1
        bytes memory keyAbovePrime = abi.encodePacked(
            bytes1(0x03),
            bytes32(SECP256K1_FIELD_PRIME + 1)
        );
        vm.expectRevert(INoxCompute.InvalidKmsPublicKey.selector);
        vm.prank(upgrader);
        noxCompute.setKmsPublicKey(keyAbovePrime);

        // X-coordinate == all 0xff bytes (max uint256, far above the field prime)
        bytes memory keyAllFf = abi.encodePacked(bytes1(0x02), bytes32(type(uint256).max));
        vm.expectRevert(INoxCompute.InvalidKmsPublicKey.selector);
        vm.prank(upgrader);
        noxCompute.setKmsPublicKey(keyAllFf);
    }

    // ============ setGateway ============

    function test_SetGateway() public {
        assertTrue(noxCompute.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(upgrader);
        vm.expectEmit();
        emit INoxCompute.GatewayUpdated(newGateway);
        noxCompute.setGateway(newGateway);
        assertTrue(noxCompute.gateway() == newGateway);
    }

    function test_RevertWhen_SetGateway_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        address newGateway = makeAddr("newGateway");
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.UPGRADER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.setGateway(newGateway);
    }

    function test_RevertWhen_SetGateway_ZeroAddress() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(upgrader);
        noxCompute.setGateway(address(0));
    }

    // ============ setProofExpirationDuration ============

    function test_SetProofExpirationDuration() public {
        // Default is set during initialization
        assertEq(noxCompute.proofExpirationDuration(), 1 hours);

        uint256 newDuration = 2 hours;
        vm.prank(upgrader);
        vm.expectEmit();
        emit INoxCompute.ProofExpirationDurationUpdated(newDuration);
        noxCompute.setProofExpirationDuration(newDuration);
        assertEq(noxCompute.proofExpirationDuration(), newDuration);
    }

    function test_RevertWhen_SetProofExpirationDuration_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.UPGRADER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.setProofExpirationDuration(2 hours);
    }

    // ============ beginDefaultAdminTransfer ============

    function test_BeginDefaultAdminTransfer_AndAccept() public {
        bytes32 adminRole = noxCompute.DEFAULT_ADMIN_ROLE();
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        noxCompute.beginDefaultAdminTransfer(newAdmin);
        // No transfer delay is configured, acceptance is possible in the next block
        vm.warp(block.timestamp + 1);
        vm.prank(newAdmin);
        noxCompute.acceptDefaultAdminTransfer();
        assertEq(noxCompute.defaultAdmin(), newAdmin);
        assertTrue(noxCompute.hasRole(adminRole, newAdmin));
        assertFalse(noxCompute.hasRole(adminRole, admin));
    }

    function test_RevertWhen_BeginDefaultAdminTransfer_ZeroAddress() public {
        vm.expectRevert(INoxCompute.DefaultAdminRoleRenouncementForbidden.selector);
        vm.prank(admin);
        noxCompute.beginDefaultAdminTransfer(address(0));
    }

    // ============ renounceRole ============

    function test_RenounceRole_UpgraderRole() public {
        bytes32 upgraderRole = noxCompute.UPGRADER_ROLE();
        assertTrue(noxCompute.hasRole(upgraderRole, upgrader));
        vm.prank(upgrader);
        noxCompute.renounceRole(upgraderRole, upgrader);
        assertFalse(noxCompute.hasRole(upgraderRole, upgrader));
    }

    // ============ _authorizeUpgrade ============

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(TestHelper.newImplementationInstance());
        vm.prank(upgrader);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        noxCompute.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradeToAndCall_UnauthorizedCaller() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        _expectMissingRoleRevert(unauthorizedUpgrader, noxCompute.UPGRADER_ROLE());
        vm.prank(unauthorizedUpgrader);
        noxCompute.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Role separation ============

    function test_Roles_AdminCannotCallUpgrader() public {
        _expectMissingRoleRevert(admin, noxCompute.UPGRADER_ROLE());
        vm.prank(admin);
        noxCompute.setGateway(makeAddr("anyGateway"));
    }

    // ============ Helpers ============

    function _expectMissingRoleRevert(address caller, bytes32 role) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                caller,
                role
            )
        );
    }
}
