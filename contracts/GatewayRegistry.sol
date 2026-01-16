// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IGatewayRegistry} from "./interfaces/IGatewayRegistry.sol";

/**
 * TODO
 */
contract GatewayRegistry is
    IGatewayRegistry,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * Initializes the proxy contract state.
     * @param initialAdmin Initial default admin address
     * @param initialUpgrader Initial upgrader address
     */
    function initialize(address initialAdmin, address initialUpgrader) public initializer {
        if (initialUpgrader == address(0)) {
            revert InvalidZeroAddress();
        }
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialUpgrader);
    }

    /**
     * Authorizes contract upgrades only by accounts with the role `UPGRADER_ROLE`.
     */
    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
