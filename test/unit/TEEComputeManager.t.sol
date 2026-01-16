// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";

contract TEEComputeManagerTest is Test {
    TEEComputeManager teeComputeManager;
    address initialOwner = makeAddr("owner");
    address acl = makeAddr("acl");

    function setUp() public {
        teeComputeManager = _deployNewProxy();
        teeComputeManager.initialize(initialOwner, initialUpgrader);
        vm.label(initialOwner, "initialOwner");
        vm.label(initialUpgrader, "initialUpgrader");
        vm.label(address(teeComputeManager), "teeComputeManager");
    }

    // initialize

    function test_Initialize() public view {
        assertTrue(teeComputeManager.hasRole(teeComputeManager.DEFAULT_ADMIN_ROLE(), initialOwner));
        assertTrue(teeComputeManager.hasRole(teeComputeManager.UPGRADER_ROLE(), initialUpgrader));
    }

    function test_RevertWhen_Initialize_WithZeroAddresses() public {
        TEEComputeManager proxy = _deployNewProxy();
        vm.expectRevert(ITEEComputeManager.InvalidZeroAddress.selector);
        proxy.initialize(address(0), initialUpgrader);
        vm.expectRevert(ITEEComputeManager.InvalidZeroAddress.selector);
        proxy.initialize(initialOwner, address(0));
    }

    function test_RevertWhen_Initialize_Twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        teeComputeManager.initialize(initialOwner, initialUpgrader);
    }

    // _authorizeUpgrade

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new TEEComputeManager());
        vm.prank(initialUpgrader);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        teeComputeManager.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_AuthorizeUpgrade_WithUnauthorizedUpgrader() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                teeComputeManager.UPGRADER_ROLE()
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
