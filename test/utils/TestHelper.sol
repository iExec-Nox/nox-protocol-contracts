// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ACL} from "../../contracts/ACL.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {TEEType} from "../../contracts/shared/TypeUtils.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";

library TestHelper {
    address internal constant NOX_COMPUTE_ADDRESS = address(Nox.NOX_COMPUTE);
    address internal constant ACL_ADDRESS = address(Nox.ACL);

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
     * @notice Deploys ACL and NoxCompute at the hardcoded addresses used by Nox.
     * TODO: Use vm.broadcastRawTransaction(deployCreateXTx) to deploy CreateX in tests.
     * @dev Uses vm.etch to place proxy bytecode at the expected addresses, ensuring Nox
     *      library calls work correctly in tests.
     */
    function deploy(
        address owner,
        address gateway
    ) internal returns (ACL acl, NoxCompute noxCompute) {
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

        // Deploy NoxCompute implementation (with ACL address as immutable)
        address noxComputeImplementation = address(new NoxCompute(ACL_ADDRESS));

        // Deploy a temporary proxy to get its runtime bytecode
        ERC1967Proxy noxComputeProxyTemp = new ERC1967Proxy(noxComputeImplementation, "");

        // Etch the proxy bytecode at the hardcoded NoxCompute address
        vm.etch(NOX_COMPUTE_ADDRESS, address(noxComputeProxyTemp).code);
        // Set the implementation slot
        vm.store(
            NOX_COMPUTE_ADDRESS,
            IMPLEMENTATION_SLOT,
            bytes32(uint256(uint160(noxComputeImplementation)))
        );

        noxCompute = NoxCompute(NOX_COMPUTE_ADDRESS);
        noxCompute.initialize(owner);

        // Configure contracts
        vm.prank(owner);
        acl.setNoxCompute(NOX_COMPUTE_ADDRESS);
        vm.prank(owner);
        noxCompute.setGateway(gateway);

        // Set labels
        vm.label(owner, "owner");
        vm.label(gateway, "gateway");
        vm.label(ACL_ADDRESS, "acl");
        vm.label(NOX_COMPUTE_ADDRESS, "noxCompute");

        return (acl, noxCompute);
    }

    function deployProxy(address implementation) internal returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        return address(proxy);
    }

    function getVm() internal pure returns (Vm) {
        return Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    }
}
