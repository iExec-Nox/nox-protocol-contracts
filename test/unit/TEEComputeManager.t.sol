// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, Vm} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {IACL} from "../../contracts/interfaces/IACL.sol";
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

    /// @dev Creates a handle with the specified TEEType encoded in byte 30
    function _createHandle(TEEType teeType, uint256 seed) internal pure returns (bytes32) {
        bytes32 handle = keccak256(abi.encodePacked(seed));
        // Clear bytes 21-31 and set the type in byte 30
        handle = handle & 0xffffffffffffffffffffffffffffffffffffffffff0000000000000000000000;
        handle = handle | (bytes32(uint256(uint8(teeType))) << 8);
        return handle;
    }

    // initialize

    function test_Initialize() public view {
        assertTrue(teeComputeManager.owner() == owner);
        assertTrue(teeComputeManager.acl() == address(mockAcl));
        (
            , // bytes1 fields
            string memory name,
            string memory version,
            , // uint256 chainId
            , // address verifyingContract
            , // uint256[] memory extensions, // bytes32 salt

        ) = teeComputeManager.eip712Domain();
        assertTrue(keccak256(bytes(name)) == keccak256(bytes("TEEComputeManager")));
        assertTrue(keccak256(bytes(version)) == keccak256(bytes("1")));
    }

    function test_RevertWhen_Initialize_Twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        teeComputeManager.initialize(owner);
    }

    // setAcl

    function test_SetAcl() public {
        assertTrue(teeComputeManager.acl() == address(mockAcl));
        address newAcl = makeAddr("newAcl");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.ACLUpdated(newAcl);
        teeComputeManager.setAcl(newAcl);
        assertTrue(teeComputeManager.acl() == newAcl);
    }

    function test_RevertWhen_SetAcl_WithUnauthorizedCaller() public {
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

    // _authorizeUpgrade

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new TEEComputeManager());
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        teeComputeManager.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_AuthorizeUpgrade_WithUnauthorizedUpgrader() public {
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

    function _deployNewProxy() internal returns (TEEComputeManager) {
        TEEComputeManager implementation = new TEEComputeManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        return TEEComputeManager(address(proxy));
    }

    // ============ trivialEncrypt ============

    function test_TrivialEncrypt_Uint256() public {
        uint256 plaintext = 12345;
        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.trivialEncrypt(plaintext, TEEType.Uint256);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("PlaintextToEncrypted(address,uint256,uint8,bytes32)"));
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

    // ============ add ============

    function test_Add_Success() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.add(lhs, rhs);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Add(address,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_Add_RevertWhen_LhsNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        // Only allow rhs, not lhs
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, lhs, caller));
        teeComputeManager.add(lhs, rhs);
    }

    function test_Add_RevertWhen_RhsNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        // Only allow lhs, not rhs
        mockAcl.setAllowed(lhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, rhs, caller));
        teeComputeManager.add(lhs, rhs);
    }

    function test_Add_RevertWhen_IncompatibleTypes() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Int256, 2);

        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.add(lhs, rhs);
    }

    function test_Add_RevertWhen_UnsupportedType() public {
        bytes32 lhs = _createHandle(TEEType.Bool, 1);
        bytes32 rhs = _createHandle(TEEType.Bool, 2);

        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.add(lhs, rhs);
    }

    // ============ sub ============

    function test_Sub_Success() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.sub(lhs, rhs);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Sub(address,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_Sub_RevertWhen_ACLNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, lhs, caller));
        teeComputeManager.sub(lhs, rhs);
    }

    // ============ div ============

    function test_Div_Success() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        mockAcl.setAllowed(lhs, caller, true);
        mockAcl.setAllowed(rhs, caller, true);

        vm.prank(caller);
        vm.recordLogs();
        bytes32 result = teeComputeManager.div(lhs, rhs);
        assertTrue(result != bytes32(0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Div(address,bytes32,bytes32,bytes32)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(caller))));
    }

    function test_Div_RevertWhen_DivisionByZero() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = bytes32(0);

        mockAcl.setAllowed(lhs, caller, true);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.DivisionByZero.selector);
        teeComputeManager.div(lhs, rhs);
    }

    function test_Div_RevertWhen_ACLNotAllowed() public {
        bytes32 lhs = _createHandle(TEEType.Uint256, 1);
        bytes32 rhs = _createHandle(TEEType.Uint256, 2);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, lhs, caller));
        teeComputeManager.div(lhs, rhs);
    }

    // ============ select ============

    function test_Select_Success() public {
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

    function test_Select_RevertWhen_ConditionNotBool() public {
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

    function test_Select_RevertWhen_IncompatibleTypes() public {
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

    function test_Select_RevertWhen_ACLNotAllowed() public {
        bytes32 condition = _createHandle(TEEType.Bool, 1);
        bytes32 ifTrue = _createHandle(TEEType.Uint256, 2);
        bytes32 ifFalse = _createHandle(TEEType.Uint256, 3);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, condition, caller));
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }
}
