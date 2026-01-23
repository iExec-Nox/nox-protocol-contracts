// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, Vm} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TEEType.sol";
import {MockACL} from "../../contracts/mock/MockACL.sol";

contract TEEComputeManagerTest is Test {
    TEEComputeManager teeComputeManager;
    MockACL mockAcl;
    address owner = makeAddr("owner");
    address caller = makeAddr("caller");

    function setUp() public {
        mockAcl = new MockACL();
        teeComputeManager = _deployNewProxy();
        teeComputeManager.initialize(owner);
        vm.prank(owner);
        teeComputeManager.setAcl(address(mockAcl));
    }

    // ============ initialize Tests ============

    function test_Initialize() public view {
        assertEq(teeComputeManager.owner(), owner);
        assertEq(teeComputeManager.acl(), address(mockAcl));
        (, string memory name, string memory version, , , , ) = teeComputeManager.eip712Domain();
        assertEq(keccak256(bytes(name)), keccak256(bytes("TEEComputeManager")));
        assertEq(keccak256(bytes(version)), keccak256(bytes("1")));
    }

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        teeComputeManager.initialize(owner);
    }

    // ============ setAcl Tests ============

    function test_SetAcl() public {
        address newAcl = makeAddr("newAcl");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.ACLUpdated(newAcl);
        teeComputeManager.setAcl(newAcl);
        assertEq(teeComputeManager.acl(), newAcl);
    }

    function test_RevertWhen_SetAcl_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedCaller);
        teeComputeManager.setAcl(makeAddr("newAcl"));
    }

    // ============ add Tests ============

    function test_Add() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);
        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Add(caller, lhs, rhs, bytes32(0));
        bytes32 result = teeComputeManager.add(lhs, rhs);

        assertTrue(result != bytes32(0));
    }

    function test_RevertWhen_Add_LhsNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, lhs, caller)
        );
        teeComputeManager.add(lhs, rhs);
    }

    function test_RevertWhen_Add_RhsNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);
        mockAcl.setAllowed(lhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, rhs, caller)
        );
        teeComputeManager.add(lhs, rhs);
    }

    function test_RevertWhen_Add_IncompatibleTypes() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Int256, 2);
        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.add(lhs, rhs);
    }

    function test_RevertWhen_Add_UnsupportedType() public {
        bytes32 lhs = _createHandle(TEEType.Bool, 1);
        bytes32 rhs = _createHandle(TEEType.Bool, 2);
        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.add(lhs, rhs);
    }

    // ============ sub Tests ============

    function test_Sub() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);
        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Sub(caller, lhs, rhs, bytes32(0));
        bytes32 result = teeComputeManager.sub(lhs, rhs);

        assertTrue(result != bytes32(0));
    }

    function test_RevertWhen_Sub_ACLNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, lhs, caller)
        );
        teeComputeManager.sub(lhs, rhs);
    }

    // ============ div Tests ============

    function test_Div() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);
        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Div(caller, lhs, rhs, bytes32(0));
        bytes32 result = teeComputeManager.div(lhs, rhs);

        assertTrue(result != bytes32(0));
    }

    function test_RevertWhen_Div_DivisionByZero() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        mockAcl.setAllowed(lhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.DivisionByZero.selector);
        teeComputeManager.div(lhs, bytes32(0));
    }

    function test_RevertWhen_Div_ACLNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, lhs, caller)
        );
        teeComputeManager.div(lhs, rhs);
    }

    // ============ _authorizeUpgrade Tests ============

    function test_UpgradeToAndCall() public {
        address newImplementation = address(new TEEComputeManager());
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        teeComputeManager.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradeToAndCall_UnauthorizedCaller() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedUpgrader);
        teeComputeManager.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Test Helpers ============

    function _deployNewProxy() internal returns (TEEComputeManager) {
        TEEComputeManager implementation = new TEEComputeManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        return TEEComputeManager(address(proxy));
    }

    function _createHandle(TEEType teeType, uint256 seed) internal pure returns (bytes32) {
        bytes32 handle = keccak256(abi.encodePacked(seed));
        handle = handle & 0xffffffffffffffffffffffffffffffffffffffffff0000000000000000000000;
        handle = handle | (bytes32(uint256(uint8(teeType))) << 8);
        return handle;
    }
}
