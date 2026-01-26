// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ACL} from "../../contracts/ACL.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TEEType.sol";

library TestHelper {
    function createHandle(TEEType teeType) internal view returns (bytes32 handle) {
        return createHandle(block.chainid, teeType);
    }

    function createHandle(uint256 chainId, TEEType teeType) internal view returns (bytes32 handle) {
        return
            bytes32(
                abi.encodePacked(
                    bytes26(uint208(block.timestamp)), // Random pre-handle
                    bytes4(uint32(chainId)),
                    bytes1(uint8(teeType)),
                    bytes1(0x00) // Version 0
                )
            );
    }

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
