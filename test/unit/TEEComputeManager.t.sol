// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, Vm} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TEEType.sol";
import {MockACL} from "../../contracts/mock/MockACL.sol";

contract TEEComputeManagerTest is Test {
    TEEComputeManager teeComputeManager;
    MockACL mockAcl;
    address owner = makeAddr("owner");
    address caller = makeAddr("caller");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    uint256 createdAt = block.timestamp;
    bytes32 handle =
        bytes32(
            bytes.concat(
                bytes26(uint208(1234567890)),
                bytes4(uint32(block.chainid)),
                bytes1(uint8(TEEType.Uint256)),
                bytes1(0x00)
            )
        );

    function setUp() public {
        mockAcl = new MockACL();
        teeComputeManager = _deployNewProxy();
        teeComputeManager.initialize(owner);
        vm.startPrank(owner);
        teeComputeManager.setAcl(address(mockAcl));
        teeComputeManager.setGateway(gateway);
        vm.stopPrank();
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

    function test_RevertWhen_SetAcl_ZeroAddress() public {
        vm.expectRevert(ITEEComputeManager.InvalidZeroAddress.selector);
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
        vm.expectRevert(ITEEComputeManager.InvalidZeroAddress.selector);
        vm.prank(owner);
        teeComputeManager.setGateway(address(0));
    }

    // ============ validateProof Tests ============

    function test_ValidateProof() public view {
        bytes memory proof = _buildProof(
            handle,
            owner,
            address(mockAcl),
            createdAt,
            gatewayPrivateKey
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_HandleTypeMismatch() public {
        bytes memory proof = _buildProof(
            handle,
            owner,
            address(mockAcl),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Handle type mismatch"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Bool);
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
        bytes memory proof = _buildProof(
            handle,
            badOwner,
            address(mockAcl),
            createdAt,
            gatewayPrivateKey
        );
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
        bytes memory proof = _buildProof(handle, owner, address(mockAcl), createdAt, badSigner);
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
        bytes32 h = keccak256(abi.encodePacked(seed));
        h = h & 0xffffffffffffffffffffffffffffffffffffffffff0000000000000000000000;
        h = h | (bytes32(uint256(uint8(teeType))) << 8);
        return h;
    }

    function _buildProof(
        bytes32 handle_,
        address owner_,
        address acl_,
        uint256 createdAt_,
        uint256 signerPrivateKey
    ) internal view returns (bytes memory) {
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
