// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ACL} from "../../contracts/ACL.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {TEEType} from "../../contracts/shared/TypeUtils.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";

library TestHelper {
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
     * Builds a valid proof for the given parameters, signed by the given private key.
     */
    function buildProof(
        address noxComputeAddress,
        bytes32 handle,
        address owner,
        address app,
        uint256 createdAt,
        uint256 signerPrivateKey
    ) internal view returns (bytes memory) {
        Vm vm = getVm();
        NoxCompute noxCompute = NoxCompute(noxComputeAddress);
        // HandleProof(bytes32 handle,address owner,address app,uint256 createdAt)
        bytes32 structHash = keccak256(
            abi.encode(noxCompute.HANDLE_PROOF_TYPEHASH(), handle, owner, app, createdAt)
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(noxCompute.domainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(bytes20(owner), bytes20(app), bytes32(createdAt), r, s, v);
    }

    /**
     * @notice Deploys ACL and NoxCompute at the addresses resolved by Nox for the current chain.
     * TODO: Use vm.broadcastRawTransaction(deployCreateXTx) to deploy CreateX in tests.
     * @dev Uses vm.etch to place proxy bytecode at the expected addresses, ensuring Nox
     *      library calls work correctly in tests.
     */
    function deploy(
        address owner,
        address gateway
    ) internal returns (ACL acl, NoxCompute noxCompute) {
        Vm vm = getVm();
        address aclAddress = address(Nox._acl());
        address noxComputeAddress = address(Nox._compute());

        // Deploy ACL implementation
        address aclImplementation = address(new ACL());

        // Deploy a temporary proxy to get its runtime bytecode
        ERC1967Proxy aclProxyTemp = new ERC1967Proxy(aclImplementation, "");

        // Etch the proxy bytecode at the ACL address resolved by Nox
        vm.etch(aclAddress, address(aclProxyTemp).code);
        // Set the implementation slot
        vm.store(aclAddress, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(aclImplementation))));

        acl = ACL(aclAddress);
        acl.initialize(owner);

        // Deploy NoxCompute implementation (with ACL address as immutable)
        address noxComputeImplementation = address(new NoxCompute(aclAddress));

        // Deploy a temporary proxy to get its runtime bytecode
        ERC1967Proxy noxComputeProxyTemp = new ERC1967Proxy(noxComputeImplementation, "");

        // Etch the proxy bytecode at the NoxCompute address resolved by Nox
        vm.etch(noxComputeAddress, address(noxComputeProxyTemp).code);
        // Set the implementation slot
        vm.store(
            noxComputeAddress,
            IMPLEMENTATION_SLOT,
            bytes32(uint256(uint160(noxComputeImplementation)))
        );

        noxCompute = NoxCompute(noxComputeAddress);
        noxCompute.initialize(owner, vm.randomBytes(33));

        // Configure contracts
        vm.prank(owner);
        acl.setNoxCompute(noxComputeAddress);
        vm.prank(owner);
        noxCompute.setGateway(gateway);

        // Set labels
        vm.label(owner, "owner");
        vm.label(gateway, "gateway");
        vm.label(aclAddress, "acl");
        vm.label(noxComputeAddress, "noxCompute");

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
