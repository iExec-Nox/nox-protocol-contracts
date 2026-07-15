// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {HandleUtils} from "../../contracts/utils/HandleUtils.sol";
import {TEEType, TypeUtils} from "../../contracts/utils/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxComputeTest is Test {
    // ERC-7201 storage location of OZ `Initializable`; low 8 bytes hold `_initialized`.
    bytes32 constant _INITIALIZABLE_SLOT =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    bytes kmsKey = abi.encodePacked(bytes1(0x02), keccak256("kms-key"));
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    NoxCompute noxCompute;

    function setUp() public {
        noxCompute = TestHelper.deploy(admin, upgrader, gateway, kmsKey);
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertTrue(noxCompute.hasRole(noxCompute.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(noxCompute.hasRole(noxCompute.UPGRADER_ROLE(), upgrader));
        assertEq(noxCompute.proofExpirationDuration(), 1 hours);
        (
            , // bytes1 fields
            string memory name,
            string memory version,
            , // uint256 chainId
            , // address verifyingContract
            , // uint256[] memory extensions, // bytes32 salt

        ) = noxCompute.eip712Domain();
        assertTrue(keccak256(bytes(name)) == keccak256(bytes("NoxCompute")));
        assertTrue(keccak256(bytes(version)) == keccak256(bytes("1")));
    }

    function test_Initialize_ShouldEmitEvents() public {
        _checkEmitKmsPublicKeyUpdated();
        _checkEmitGatewayUpdated();
        _checkEmitProofExpirationDurationUpdated();
        _checkEmitZeroHandleSeeds();
        _checkEmitRoleGranted();
    }

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        noxCompute.initialize(admin, upgrader, kmsKey, gateway);
    }

    function test_Initialize_UsesOneShotInitializer() public view {
        // `initialize` must use the `initializer` modifier (landing at version 1), NOT a
        // `reinitializer`. It is unguarded and grants roles, so it must be callable only on a
        // truly fresh proxy.
        uint64 initializedVersion = uint64(
            uint256(vm.load(address(noxCompute), _INITIALIZABLE_SLOT))
        );
        assertEq(initializedVersion, 1);
    }

    function test_RevertWhen_Initialize_InvalidKmsPublicKeyLength() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        // 0 bytes (empty)
        vm.expectRevert(INoxCompute.InvalidKmsPublicKeyLength.selector);
        TestHelper.deployProxy(address(impl), admin, upgrader, new bytes(0), gateway);
        // 32 bytes (too short)
        vm.expectRevert(INoxCompute.InvalidKmsPublicKeyLength.selector);
        TestHelper.deployProxy(address(impl), admin, upgrader, new bytes(32), gateway);
        // 34 bytes (too long)
        vm.expectRevert(INoxCompute.InvalidKmsPublicKeyLength.selector);
        TestHelper.deployProxy(address(impl), admin, upgrader, new bytes(34), gateway);
    }

    function test_RevertWhen_Initialize_ZeroKmsPublicKey() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectRevert(INoxCompute.InvalidKmsPublicKey.selector);
        TestHelper.deployProxy(address(impl), admin, upgrader, new bytes(33), gateway);
    }

    function test_RevertWhen_Initialize_ZeroAdmin() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        TestHelper.deployProxy(address(impl), address(0), upgrader, kmsKey, gateway);
    }

    function test_RevertWhen_Initialize_ZeroUpgrader() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        TestHelper.deployProxy(address(impl), admin, address(0), kmsKey, gateway);
    }

    function test_RevertWhen_Initialize_ZeroGateway() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        TestHelper.deployProxy(address(impl), admin, upgrader, kmsKey, address(0));
    }

    function test_Reinitialize_ByUpgrader() public {
        vm.prank(upgrader);
        noxCompute.reinitialize();
        uint64 initializedVersion = uint64(
            uint256(vm.load(address(noxCompute), _INITIALIZABLE_SLOT))
        );
        assertEq(initializedVersion, 4);
    }

    function test_RevertWhen_Reinitialize_NotUpgrader() public {
        address notUpgrader = makeAddr("notUpgrader");
        bytes32 upgraderRole = noxCompute.UPGRADER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                notUpgrader,
                upgraderRole
            )
        );
        vm.prank(notUpgrader);
        noxCompute.reinitialize();
    }

    // ============ Helpers ============

    function _checkEmitKmsPublicKeyUpdated() private {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectEmit();
        emit INoxCompute.KmsPublicKeyUpdated(kmsKey);
        TestHelper.deployProxy(address(impl), admin, upgrader, kmsKey, gateway);
    }

    function _checkEmitGatewayUpdated() private {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectEmit();
        emit INoxCompute.GatewayUpdated(gateway);
        TestHelper.deployProxy(address(impl), admin, upgrader, kmsKey, gateway);
    }

    function _checkEmitProofExpirationDurationUpdated() private {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectEmit();
        emit INoxCompute.ProofExpirationDurationUpdated(1 hours);
        TestHelper.deployProxy(address(impl), admin, upgrader, kmsKey, gateway);
    }

    function _checkEmitZeroHandleSeeds() private {
        TEEType[] memory types = TestHelper.allCurrentlySupportedTypes();
        for (uint i = 0; i < types.length; i++) {
            vm.expectEmit(false, false, false, true);
            emit INoxCompute.WrapAsPublicHandle(
                address(0),
                bytes32(0),
                types[i],
                HandleUtils.zeroHandle(types[i])
            );
        }
        TestHelper.newProxyInstance();
    }

    function _checkEmitRoleGranted() private {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(noxCompute.DEFAULT_ADMIN_ROLE(), admin, address(0));
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(noxCompute.UPGRADER_ROLE(), upgrader, address(0));
        TestHelper.deployProxy(address(impl), admin, upgrader, kmsKey, gateway);
    }
}
