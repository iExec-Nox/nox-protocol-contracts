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
    address owner = makeAddr("owner");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    NoxCompute noxCompute;

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, owner, gateway);
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertTrue(noxCompute.hasRole(noxCompute.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(noxCompute.hasRole(noxCompute.UPGRADER_ROLE(), owner));
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

    function test_Initialize_ShouldEmitZeroHandleSeeds() public {
        TEEType[] memory types = TypeUtils.allCurrentlySupportedTypes();
        for (uint i = 0; i < types.length; i++) {
            vm.expectEmit(false, false, false, true);
            emit INoxCompute.WrapAsPublicHandle(
                address(0), // ignored
                bytes32(0),
                types[i],
                HandleUtils.zeroHandle(types[i])
            );
        }
        // Initialize function is called when the proxy is deployed.
        TestHelper.newProxyInstance();
    }

    function test_Initialize_ShouldEmitRoleGranted() public {
        address admin = makeAddr("admin");
        address upgrader = makeAddr("upgrader");
        NoxCompute impl = TestHelper.newImplementationInstance();
        bytes memory kmsKey = abi.encodePacked(bytes1(0x02), keccak256("test-kms-key"));
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(noxCompute.DEFAULT_ADMIN_ROLE(), admin, address(0));
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(noxCompute.UPGRADER_ROLE(), upgrader, address(0));
        TestHelper.deployProxy(address(impl), admin, upgrader, kmsKey, makeAddr("gateway"));
    }

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        noxCompute.initialize(
            owner,
            owner,
            abi.encodePacked(bytes1(0x02), keccak256("reinit-kms-key")),
            makeAddr("gateway")
        );
    }

    function test_RevertWhen_Initialize_EmptyKmsPublicKey() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectRevert(INoxCompute.InvalidEmptyBytes.selector);
        TestHelper.deployProxy(
            address(impl),
            address(this),
            address(this),
            new bytes(0),
            makeAddr("gateway")
        );
    }

    function test_RevertWhen_Initialize_ZeroAdmin() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        bytes memory kmsKey = abi.encodePacked(bytes1(0x02), keccak256("test-kms-key"));
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        TestHelper.deployProxy(
            address(impl),
            address(0),
            address(this),
            kmsKey,
            makeAddr("gateway")
        );
    }

    function test_RevertWhen_Initialize_ZeroUpgrader() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        bytes memory kmsKey = abi.encodePacked(bytes1(0x02), keccak256("test-kms-key"));
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        TestHelper.deployProxy(
            address(impl),
            address(this),
            address(0),
            kmsKey,
            makeAddr("gateway")
        );
    }

    function test_RevertWhen_Initialize_ZeroGateway() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        bytes memory kmsKey = abi.encodePacked(bytes1(0x02), keccak256("test-kms-key"));
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        TestHelper.deployProxy(address(impl), address(this), address(this), kmsKey, address(0));
    }

    // ============ initializeV2 ============

    function test_InitializeV2() public {
        NoxCompute proxy = TestHelper.newProxyInstance();
        TEEType[] memory types = TypeUtils.allCurrentlySupportedTypes();
        for (uint i = 0; i < types.length; i++) {
            vm.expectEmit(false, false, false, true);
            emit INoxCompute.WrapAsPublicHandle(
                address(0), // ignored
                bytes32(0),
                types[i],
                HandleUtils.zeroHandle(types[i])
            );
        }
        proxy.initializeV2();
    }

    function test_RevertWhen_InitializeV2_AlreadyCalled() public {
        NoxCompute proxy = TestHelper.newProxyInstance();
        proxy.initializeV2();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        proxy.initializeV2();
    }

    // ============ initializeV3 ============

    function test_InitializeV3() public {
        address admin = makeAddr("newAdmin");
        address upgrader = makeAddr("newUpgrader");
        NoxCompute proxy = TestHelper.newProxyInstance();
        // Simulate legacy Ownable storage with a non-zero owner slot
        // TODO: remove `slither-disable-next-line` once Slither supports the `erc7201` builtin (added in solc 0.8.35).
        // slither-disable-next-line uninitialized-state
        bytes32 ownableSlot = bytes32(erc7201("openzeppelin.storage.Ownable"));
        vm.store(address(proxy), ownableSlot, bytes32(uint256(uint160(makeAddr("old-owner")))));
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(proxy.DEFAULT_ADMIN_ROLE(), admin, address(0));
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(proxy.UPGRADER_ROLE(), upgrader, address(0));
        proxy.initializeV3(admin, upgrader);
        assertTrue(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(proxy.hasRole(proxy.UPGRADER_ROLE(), upgrader));
        assertEq(vm.load(address(proxy), ownableSlot), bytes32(0));
    }

    function test_RevertWhen_InitializeV3_AlreadyCalled() public {
        NoxCompute proxy = TestHelper.newProxyInstance();
        proxy.initializeV3(makeAddr("admin"), makeAddr("upgrader"));
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        proxy.initializeV3(makeAddr("admin"), makeAddr("upgrader"));
    }

    function test_RevertWhen_InitializeV3_ZeroAdmin() public {
        NoxCompute proxy = TestHelper.newProxyInstance();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        proxy.initializeV3(address(0), makeAddr("upgrader"));
    }

    function test_RevertWhen_InitializeV3_ZeroUpgrader() public {
        NoxCompute proxy = TestHelper.newProxyInstance();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        proxy.initializeV3(makeAddr("admin"), address(0));
    }
}
