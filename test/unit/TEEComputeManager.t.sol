// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TEEType.sol";

contract TEEComputeManagerTest is Test {
    TEEComputeManager teeComputeManager;
    address owner = makeAddr("owner");
    address acl = makeAddr("acl");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    uint256 createdAt = block.timestamp;
    bytes32 handle =
        bytes32(
            bytes.concat(
                bytes26(uint208(1234567890)), // Random pre-handle
                bytes4(uint32(block.chainid)),
                bytes1(uint8(TEEType.Uint256)), // Type 3
                bytes1(0x00) // Version 0
            )
        );

    function setUp() public {
        teeComputeManager = _deployNewProxy();
        teeComputeManager.initialize(owner);
        vm.startPrank(owner);
        teeComputeManager.setAcl(acl);
        teeComputeManager.setGateway(gateway);
        vm.stopPrank();
        vm.label(owner, "owner");
        vm.label(acl, "acl");
        vm.label(gateway, "gateway");
        vm.label(address(teeComputeManager), "teeComputeManager");
    }

    // initialize

    function test_Initialize() public view {
        assertTrue(teeComputeManager.owner() == owner);
        assertTrue(teeComputeManager.acl() == acl);
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

    function test_Initialize_RevertWhen_DoubleInit() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        teeComputeManager.initialize(owner);
    }

    // setAcl

    function test_SetAcl() public {
        assertTrue(teeComputeManager.acl() == acl);
        address newAcl = makeAddr("newAcl");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.ACLUpdated(newAcl);
        teeComputeManager.setAcl(newAcl);
        assertTrue(teeComputeManager.acl() == newAcl);
    }

    function test_SetAcl_RevertWhen_UnauthorizedCaller() public {
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

    function test_SetAcl_RevertWhen_ZeroAddress() public {
        vm.expectRevert(ITEEComputeManager.InvalidZeroAddress.selector);
        vm.prank(owner);
        teeComputeManager.setAcl(address(0));
    }

    // setGateway

    function test_SetGateway() public {
        assertTrue(teeComputeManager.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.GatewayUpdated(newGateway);
        teeComputeManager.setGateway(newGateway);
        assertTrue(teeComputeManager.gateway() == newGateway);
    }

    function test_SetGateway_RevertWhen_UnauthorizedCaller() public {
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

    function test_SetGateway_RevertWhen_ZeroAddress() public {
        vm.expectRevert(ITEEComputeManager.InvalidZeroAddress.selector);
        vm.prank(owner);
        teeComputeManager.setGateway(address(0));
    }

    // validateProof

    function test_ValidateProof() public view {
        bytes memory proof = _buildProof(handle, owner, acl, createdAt, gatewayPrivateKey);
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_ValidateProof_RevertWhen_HandleTypeMismatch() public {
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

    function test_ValidateProof_RevertWhen_InvalidProofLength() public {
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

    function test_ValidateProof_RevertWhen_InvalidAclInProof() public {
        address badAcl = makeAddr("badAcl");
        bytes memory proof = _buildProof(handle, owner, badAcl, createdAt, gatewayPrivateKey);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.InvalidProof.selector, proof, "ACL mismatch")
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_ValidateProof_RevertWhen_InvalidOwnerInProof() public {
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

    function test_ValidateProof_RevertWhen_InvalidSigner() public {
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

    function _buildProof(
        bytes32 handle_,
        address owner_,
        address acl_,
        uint256 createdAt_,
        uint256 signerPrivateKey
    ) internal view returns (bytes memory) {
        // HandleProof(bytes32 handle,address owner,address acl,uint256 createdAt)
        bytes32 digest = _buildDigest(handle_, owner_, acl_, createdAt_);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        return bytes.concat(bytes20(owner_), bytes20(acl_), bytes32(createdAt_), signature);
    }

    function _buildDigest(
        bytes32 handle_,
        address owner_,
        address acl_,
        uint256 createdAt_
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(teeComputeManager.HANDLE_PROOF_TYPEHASH(), handle_, owner_, acl_, createdAt_)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", teeComputeManager.domainSeparator(), structHash)
            );
    }
}
