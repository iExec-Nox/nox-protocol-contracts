// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ACL} from "../../contracts/ACL.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";

library TestSetup {
    function deploy(
        address owner,
        address gateway
    ) internal returns (ACL acl, TEEComputeManager teeComputeManager) {
        Vm vm = getVm();
        // Deploy TEEComputeManager
        address teeComputeManagerImplementation = address(new TEEComputeManager());
        teeComputeManager = TEEComputeManager(deployProxy(teeComputeManagerImplementation));
        // Deploy ACL
        address aclImplementation = address(new ACL());
        acl = ACL(deployProxy(aclImplementation));
        acl.initialize(owner, address(teeComputeManager));
        // Configure TEEComputeManager
        teeComputeManager.initialize(owner);
        vm.startPrank(owner);
        teeComputeManager.setAcl(address(acl));
        teeComputeManager.setGateway(gateway);
        vm.stopPrank();
        // Set labels
        vm.label(owner, "owner");
        vm.label(gateway, "gateway");
        vm.label(address(acl), "acl");
        vm.label(address(teeComputeManager), "teeComputeManager");
        return (acl, teeComputeManager);
    }

    function deployProxy(address implementation) internal returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        return address(proxy);
    }

    function getVm() internal pure returns (Vm) {
        return Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    }
}
