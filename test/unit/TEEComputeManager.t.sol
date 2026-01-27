// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ACL} from "../../contracts/ACL.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TEEType.sol";
import {TestHelper} from "../utils/TestHelper.sol";
import {IErrors} from "../../contracts/interfaces/IErrors.sol";

contract TEEComputeManagerTest is Test {
    address owner = makeAddr("owner");
    address caller = makeAddr("caller");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    ACL aclContract;
    address acl;
    TEEComputeManager teeComputeManager;
    uint256 createdAt = block.timestamp;
    bytes32 handle = TestHelper.createHandle(TEEType.Uint256);

    function setUp() public {
        (aclContract, teeComputeManager) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        vm.label(caller, "caller");
    }

    // ============ initialize Tests ============

    function test_Initialize() public view {
        assertEq(teeComputeManager.owner(), owner);
        assertEq(teeComputeManager.acl(), acl);
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

    function test_RevertWhen_SetAcl_ZeroAddress() public {
        vm.expectRevert(IErrors.InvalidZeroAddress.selector);
        vm.prank(owner);
        teeComputeManager.setAcl(address(0));
    }

    // ============ setGateway Tests ============

    function test_SetGateway() public {
        assertTrue(teeComputeManager.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.GatewayUpdated(newGateway);
        teeComputeManager.setGateway(newGateway);
        assertTrue(teeComputeManager.gateway() == newGateway);
    }

    function test_RevertWhen_SetGateway_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        address newGateway = makeAddr("newGateway");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedCaller);
        teeComputeManager.setGateway(newGateway);
    }

    function test_RevertWhen_SetGateway_ZeroAddress() public {
        vm.expectRevert(IErrors.InvalidZeroAddress.selector);
        vm.prank(owner);
        teeComputeManager.setGateway(address(0));
    }

    // ============ validateProof Tests ============

    function test_ValidateProof() public {
        address app = makeAddr("app");
        bytes memory proof = _buildProof(handle, owner, acl, createdAt, gatewayPrivateKey);
        vm.expectCall(acl, abi.encodeCall(ACL(acl).allowTransient, (handle, app)), 1);
        vm.prank(app);
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(ACL(acl).isAllowed(handle, app));
    }

    function test_ValidateProof_RevertWhen_ChainIdMismatch() public {
        bytes32 badHandle = TestHelper.createHandle(type(uint32).max, TEEType.Uint256);
        bytes memory proof = _buildProof(badHandle, owner, acl, createdAt, gatewayPrivateKey);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Handle chain id mismatch"
            )
        );
        teeComputeManager.validateProof(badHandle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_HandleTypeMismatch() public {
        bytes memory proof = _buildProof(handle, owner, acl, createdAt, gatewayPrivateKey);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Handle type mismatch"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Bool); // Wrong type
    }

    function test_RevertWhen_ValidateProof_InvalidProofLength() public {
        bytes memory longProof = new bytes(138);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                longProof,
                "Invalid proof length"
            )
        );
        teeComputeManager.validateProof(handle, owner, longProof, TEEType.Uint256);
        bytes memory shortProof = new bytes(136);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                shortProof,
                "Invalid proof length"
            )
        );
        teeComputeManager.validateProof(handle, owner, shortProof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidAclInProof() public {
        address badAcl = makeAddr("badAcl");
        bytes memory proof = _buildProof(handle, owner, badAcl, createdAt, gatewayPrivateKey);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.InvalidProof.selector, proof, "ACL mismatch")
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidOwnerInProof() public {
        address badOwner = makeAddr("badOwner");
        bytes memory proof = _buildProof(handle, badOwner, acl, createdAt, gatewayPrivateKey);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Owner mismatch"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidSigner() public {
        uint256 badSigner = 9999;
        bytes memory proof = _buildProof(handle, owner, acl, createdAt, badSigner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Invalid signature"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    // ============ add Tests ============

    function test_Add() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Add(caller, leftHandOperand, rightHandOperand, bytes32(0));
        bytes32 result = teeComputeManager.add(leftHandOperand, rightHandOperand);

        assertTrue(result != bytes32(0));
    }

    function test_RevertWhen_Add_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

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
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

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
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.add(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Add_UnsupportedType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.add(leftHandOperand, rightHandOperand);
    }

    // ============ sub Tests ============

    function test_Sub() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Sub(caller, leftHandOperand, rightHandOperand, bytes32(0));
        bytes32 result = teeComputeManager.sub(leftHandOperand, rightHandOperand);

        assertTrue(result != bytes32(0));
    }

    function test_RevertWhen_Sub_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

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

    function test_RevertWhen_Sub_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.ACLNotAllowed.selector,
                rightHandOperand,
                caller
            )
        );
        teeComputeManager.sub(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Sub_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.sub(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Sub_UnsupportedType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.sub(leftHandOperand, rightHandOperand);
    }

    // ============ div Tests ============

    function test_Div() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Div(caller, leftHandOperand, rightHandOperand, bytes32(0));
        bytes32 result = teeComputeManager.div(leftHandOperand, rightHandOperand);

        assertTrue(result != bytes32(0));
    }

    function test_RevertWhen_Div_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

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

    function test_RevertWhen_Div_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.ACLNotAllowed.selector,
                rightHandOperand,
                caller
            )
        );
        teeComputeManager.div(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Div_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.div(leftHandOperand, rightHandOperand);
    }

    function test_RevertWhen_Div_UnsupportedType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.div(leftHandOperand, rightHandOperand);
    }

    // ============ plaintextToEncrypted Tests ============

    function test_PlaintextToEncrypted_Bool() public {
        uint256 value = 1;
        vm.prank(caller);
        bytes32 handle = teeComputeManager.plaintextToEncrypted(value, TEEType.Bool);
        
        assertTrue(handle != bytes32(0));
        assertEq(uint8(handle[30]), uint8(TEEType.Bool));
        assertTrue(aclContract.isAllowed(handle, caller));
    }

    function test_PlaintextToEncrypted_Uint160() public {
        uint256 value = 123456789;
        vm.prank(caller);
        bytes32 handle = teeComputeManager.plaintextToEncrypted(value, TEEType.Uint160);
        
        assertTrue(handle != bytes32(0));
        assertEq(uint8(handle[30]), uint8(TEEType.Uint160));
        assertTrue(aclContract.isAllowed(handle, caller));
    }

    function test_PlaintextToEncrypted_Uint256() public {
        uint256 value = 42;
        vm.prank(caller);
        bytes32 handle = teeComputeManager.plaintextToEncrypted(value, TEEType.Uint256);
        
        assertTrue(handle != bytes32(0));
        // Verify handle has correct type
        assertEq(uint8(handle[30]), uint8(TEEType.Uint256));
        // Verify handle has correct version
        assertEq(uint8(handle[31]), 0);
        // Verify caller has transient access
        assertTrue(aclContract.isAllowed(handle, caller));
    }

    function test_PlaintextToEncrypted_Int256() public {
        uint256 value = 999;
        vm.prank(caller);
        bytes32 handle = teeComputeManager.plaintextToEncrypted(value, TEEType.Int256);
        
        assertTrue(handle != bytes32(0));
        assertEq(uint8(handle[30]), uint8(TEEType.Int256));
        assertTrue(aclContract.isAllowed(handle, caller));
    }

    function test_RevertWhen_PlaintextToEncrypted_UnsupportedType() public {
        uint256 value = 42;
        // Using Address type which is not supported for arithmetic operations
        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.UnsupportedType.selector);
        teeComputeManager.plaintextToEncrypted(value, TEEType.Address);
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
    /**
     * TODO: Add tests for private helper functions:
     *   - _typeOf
     *   - _executeArithmeticOperation
     *   - _appendMetadataToPrehandle
     **/

    function _allow(bytes32 h, address account) internal {
        vm.prank(address(teeComputeManager));
        aclContract.allowTransient(h, address(this));
        aclContract.allow(h, account);
    }

    function _buildProof(
        bytes32 handle_,
        address owner_,
        address acl_,
        uint256 createdAt_,
        uint256 signerPrivateKey
    ) internal view returns (bytes memory) {
        // HandleProof(bytes32 handle,address owner,address acl,uint256 createdAt)
        bytes32 structHash = keccak256(
            abi.encode(teeComputeManager.HANDLE_PROOF_TYPEHASH(), handle_, owner_, acl_, createdAt_)
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(
            teeComputeManager.domainSeparator(),
            structHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(bytes20(owner_), bytes20(acl_), bytes32(createdAt_), r, s, v);
    }
}
