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
        vm.label(owner, "owner");
        vm.label(address(mockAcl), "acl");
        vm.label(address(teeComputeManager), "teeComputeManager");
        vm.label(caller, "caller");
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
        assertEq(teeComputeManager.acl(), address(mockAcl));
        address newAcl = makeAddr("newAcl");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.ACLUpdated(newAcl);
        teeComputeManager.setAcl(newAcl);
        assertEq(teeComputeManager.acl(), newAcl);
    }

    function test_RevertWhen_SetAcl_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        address newAcl = makeAddr("newAcl");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedCaller);
        teeComputeManager.setAcl(newAcl);
    }

    // ============ add Tests ============

    function test_Add() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(leftHandOperand, caller, true);
        mockAcl.setAllowed(rightHandOperand, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.add(leftHandOperand, rightHandOperand);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Add(address,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_RevertWhen_Add_LhsNotAllowed() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(rightHandOperand, caller, true);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.ACLNotAllowed.selector,
                leftHandOperand,
                caller
            )
        );
        teeComputeManager.add(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Add_RhsNotAllowed() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(leftHandOperand, caller, true);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.ACLNotAllowed.selector,
                rightHandOperand,
                caller
            )
        );
        teeComputeManager.add(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Add_IncompatibleTypes() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Int256, 2);

        mockAcl.setAllowed(leftHandOperand, caller, true);
        mockAcl.setAllowed(rightHandOperand, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.add(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Add_UnsupportedType() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Bool, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Bool, 2);

        mockAcl.setAllowed(leftHandOperand, caller, true);
        mockAcl.setAllowed(rightHandOperand, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.add(leftHandOperand, rightHandOperand);
    }

    // ============ sub Tests ============

    function test_Sub() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(leftHandOperand, caller, true);
        mockAcl.setAllowed(rightHandOperand, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.sub(leftHandOperand, rightHandOperand);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Sub(address,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_RevertWhen_Sub_ACLNotAllowed() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.ACLNotAllowed.selector,
                leftHandOperand,
                caller
            )
        );
        teeComputeManager.sub(leftHandOperand, rightHandOperand);
    }

    // ============ div Tests ============

    function test_Div() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(leftHandOperand, caller, true);
        mockAcl.setAllowed(rightHandOperand, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.div(leftHandOperand, rightHandOperand);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Div(address,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_RevertWhen_Div_DivisionByZero() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = bytes32(0);

        mockAcl.setAllowed(leftHandOperand, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.DivisionByZero.selector);
        teeComputeManager.div(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Div_ACLNotAllowed() public {
        bytes32 leftHandOperand = _createHandle(TEEType.Uint256, 1);
        bytes32 rightHandOperand = _createHandle(TEEType.Uint256, 2);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.ACLNotAllowed.selector,
                leftHandOperand,
                caller
            )
        );
        teeComputeManager.div(leftHandOperand, rightHandOperand);
    }

    // ============ select Tests ============

    function test_Select() public {
        bytes32 condition = _createHandle(TEEType.Bool, 1);
        bytes32 ifTrue = _createHandle(TEEType.Uint256, 2);
        bytes32 ifFalse = _createHandle(TEEType.Uint256, 3);

        mockAcl.setAllowed(condition, caller, true);
        mockAcl.setAllowed(ifTrue, caller, true);
        mockAcl.setAllowed(ifFalse, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.select(condition, ifTrue, ifFalse);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Select(address,bytes32,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_RevertWhen_Select_ConditionNotBool() public {
        bytes32 condition = _createHandle(TEEType.Uint256, 1);
        bytes32 ifTrue = _createHandle(TEEType.Uint256, 2);
        bytes32 ifFalse = _createHandle(TEEType.Uint256, 3);

        mockAcl.setAllowed(condition, caller, true);
        mockAcl.setAllowed(ifTrue, caller, true);
        mockAcl.setAllowed(ifFalse, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IncompatibleTypes() public {
        bytes32 condition = _createHandle(TEEType.Bool, 1);
        bytes32 ifTrue = _createHandle(TEEType.Uint256, 2);
        bytes32 ifFalse = _createHandle(TEEType.Int256, 3);

        mockAcl.setAllowed(condition, caller, true);
        mockAcl.setAllowed(ifTrue, caller, true);
        mockAcl.setAllowed(ifFalse, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_ACLNotAllowed() public {
        bytes32 condition = _createHandle(TEEType.Bool, 1);
        bytes32 ifTrue = _createHandle(TEEType.Uint256, 2);
        bytes32 ifFalse = _createHandle(TEEType.Uint256, 3);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, condition, caller)
        );
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    // ============ trivialEncrypt Tests ============

    function test_TrivialEncrypt_Uint256() public {
        uint256 plaintext = 12345;
        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.trivialEncrypt(plaintext, TEEType.Uint256);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(
            logs[0].topics[0],
            keccak256("PlaintextToEncrypted(address,uint256,uint8,bytes32)")
        );
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_TrivialEncrypt_Bool() public {
        uint256 plaintext = 1;
        vm.prank(caller);
        bytes32 result = teeComputeManager.trivialEncrypt(plaintext, TEEType.Bool);
        assertTrue(result != bytes32(0));
    }

    function test_TrivialEncrypt_Address() public {
        uint256 plaintext = uint256(uint160(makeAddr("someAddress")));
        vm.prank(caller);
        bytes32 result = teeComputeManager.trivialEncrypt(plaintext, TEEType.Address);
        assertTrue(result != bytes32(0));
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
