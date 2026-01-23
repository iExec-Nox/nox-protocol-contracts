// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
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

    function setUp() public {
        teeComputeManager = _deployNewProxy();
        teeComputeManager.initialize(owner);
        vm.prank(owner);
        teeComputeManager.setAcl(acl);
        vm.label(owner, "owner");
        vm.label(acl, "acl");
        vm.label(address(teeComputeManager), "teeComputeManager");
    }

    // ============ initialize Tests ============

    function test_Initialize() public view {
        assertEq(teeComputeManager.owner(), owner);
        assertEq(teeComputeManager.acl(), acl);
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
        assertEq(teeComputeManager.acl(), acl);
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
}
