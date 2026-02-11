// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ACL} from "../../contracts/ACL.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TypeUtils.sol";

library TestHelper {
    // TODO: Read those addresses from a config file instead of hardcoding them here
    address internal constant TEE_COMPUTE_MANAGER_ADDRESS =
        0xCFf1370bD7fA13e02Fa31681947fE08Cc84ce8e1;
    address internal constant ACL_ADDRESS = 0x58b680917Dc3628C17bbda64888bcc43763FC9EF;

    // ERC1967 implementation slot
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * Generates a random unique handle with the given type.
     * @param teeType target type
     */
    function createHandle(TEEType teeType) internal view returns (bytes32 handle) {
        return createHandle(block.chainid, teeType);
    }

    /**
     * Generates a random unique handle with the given chain id and type.
     * @param chainId target chainId
     * @param teeType target type
     */
    function createHandle(uint256 chainId, TEEType teeType) internal view returns (bytes32 handle) {
        Vm vm = getVm();
        return
            bytes32(
                abi.encodePacked(
                    vm.randomBytes(26), // Random pre-handle
                    bytes4(uint32(chainId)),
                    bytes1(uint8(teeType)),
                    bytes1(0x00) // Version 0
                )
            );
    }

    /**
     * @notice Deploys ACL and TEEComputeManager at the hardcoded addresses used by TEEPrimitives.
     * @dev Uses vm.etch to place proxy bytecode at the expected addresses, ensuring TEEPrimitives
     *      library calls work correctly in tests.
     */
    function deploy(
        address owner,
        address gateway
    ) internal returns (ACL acl, TEEComputeManager teeComputeManager) {
        Vm vm = getVm();

        // Deploy ACL implementation
        address aclImplementation = address(new ACL());

        // Deploy a temporary proxy to get its runtime bytecode
        ERC1967Proxy aclProxyTemp = new ERC1967Proxy(aclImplementation, "");

        // Etch the proxy bytecode at the hardcoded ACL address
        vm.etch(ACL_ADDRESS, address(aclProxyTemp).code);
        // Set the implementation slot
        vm.store(ACL_ADDRESS, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(aclImplementation))));

        acl = ACL(ACL_ADDRESS);
        acl.initialize(owner);

        // Deploy TEEComputeManager implementation (with ACL address as immutable)
        address teeComputeManagerImplementation = address(new TEEComputeManager(ACL_ADDRESS));

        // Deploy a temporary proxy to get its runtime bytecode
        ERC1967Proxy teeComputeManagerProxyTemp = new ERC1967Proxy(
            teeComputeManagerImplementation,
            ""
        );

        // Etch the proxy bytecode at the hardcoded TEEComputeManager address
        vm.etch(TEE_COMPUTE_MANAGER_ADDRESS, address(teeComputeManagerProxyTemp).code);
        // Set the implementation slot
        vm.store(
            TEE_COMPUTE_MANAGER_ADDRESS,
            IMPLEMENTATION_SLOT,
            bytes32(uint256(uint160(teeComputeManagerImplementation)))
        );

        teeComputeManager = TEEComputeManager(TEE_COMPUTE_MANAGER_ADDRESS);
        teeComputeManager.initialize(owner);

        // Configure contracts
        vm.prank(owner);
        acl.setTeeComputeManager(TEE_COMPUTE_MANAGER_ADDRESS);
        vm.prank(owner);
        teeComputeManager.setGateway(gateway);

        // Set labels
        vm.label(owner, "owner");
        vm.label(gateway, "gateway");
        vm.label(ACL_ADDRESS, "acl");
        vm.label(TEE_COMPUTE_MANAGER_ADDRESS, "teeComputeManager");

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
