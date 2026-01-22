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

contract TEEComputeManagerTest is Test {
    TEEComputeManager teeComputeManager;
    address owner = makeAddr("owner");
    address acl = makeAddr("acl");
    address gateway = makeAddr("gateway");

    function setUp() public {
        teeComputeManager = _deployNewProxy();
        teeComputeManager.initialize(owner);
        vm.prank(owner);
        teeComputeManager.setAcl(acl);
        teeComputeManager.setGateway(gateway);
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

    // setGateway

    function test_SetGateway() public {
        assertTrue(teeComputeManager.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(owner);
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
}
