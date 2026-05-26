// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
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
        noxCompute = TestHelper.deploy(owner, gateway);
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertTrue(noxCompute.hasRole(noxCompute.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(noxCompute.hasRole(noxCompute.UPGRADER_ROLE(), owner));
        assertTrue(noxCompute.hasRole(noxCompute.PAYMENT_MANAGER_ROLE(), owner));
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

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        noxCompute.initialize(abi.encodePacked(bytes1(0x02), keccak256("reinit-kms-key")));
    }

    function test_RevertWhen_Initialize_EmptyKmsPublicKey() public {
        NoxCompute impl = TestHelper.newImplementationInstance();
        vm.expectRevert(INoxCompute.InvalidEmptyBytes.selector);
        NoxCompute(TestHelper.deployProxy(address(impl), new bytes(0)));
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
}
