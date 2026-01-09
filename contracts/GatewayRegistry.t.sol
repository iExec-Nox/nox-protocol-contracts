// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {GatewayRegistry} from "../contracts/GatewayRegistry.sol";
import {IGatewayRegistry} from "../contracts/interfaces/IGatewayRegistry.sol";

contract GatewayRegistryTest is Test {
    GatewayRegistry gatewayRegistry;
    address initialAdmin = makeAddr("admin");
    address initialUpgrader = makeAddr("upgrader");

    function setUp() public {
        gatewayRegistry = _deployNewProxy();
        gatewayRegistry.initialize(initialAdmin, initialUpgrader);
    }

    // initialize

    function test_Initialize() public view {
        assertTrue(gatewayRegistry.hasRole(gatewayRegistry.DEFAULT_ADMIN_ROLE(), initialAdmin));
        assertTrue(gatewayRegistry.hasRole(gatewayRegistry.UPGRADER_ROLE(), initialUpgrader));
    }

    function test_RevertWhen_Initialize_WithZeroAddresses() public {
        GatewayRegistry proxy = _deployNewProxy();
        vm.expectRevert(IGatewayRegistry.InvalidZeroAddress.selector);
        proxy.initialize(address(0), initialUpgrader);
        vm.expectRevert(IGatewayRegistry.InvalidZeroAddress.selector);
        proxy.initialize(initialAdmin, address(0));
    }

    function test_RevertWhen_Initialize_Twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        gatewayRegistry.initialize(initialAdmin, initialUpgrader);
    }

    // _authorizeUpgrade

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new GatewayRegistry());
        vm.prank(initialUpgrader);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        gatewayRegistry.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_AuthorizeUpgrade_WithUnauthorizedUpgrader() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                gatewayRegistry.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorizedUpgrader);
        gatewayRegistry.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    function _deployNewProxy() internal returns (GatewayRegistry) {
        GatewayRegistry implementation = new GatewayRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        return GatewayRegistry(address(proxy));
    }
}
