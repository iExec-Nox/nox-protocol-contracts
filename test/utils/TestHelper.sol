// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TEEType} from "../../contracts/shared/TypeUtils.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";

library TestHelper {
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    // ERC1967 implementation slot
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant NOX_COMPUTE_STORAGE_LOCATION =
        0x118a408ef9c0c38d6620cca4d300c2ce1c4f4cbcd93520940a6461e96acdcd00;

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
        bytes32 digest = MessageHashUtils.toTypedDataHash(_eip712DomainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(bytes20(owner), bytes20(app), bytes32(createdAt), r, s, v);
    }

    /**
     * @notice Deploys NoxCompute at the addresses resolved by Nox for the current chain.
     * TODO: Use vm.broadcastRawTransaction(deployCreateXTx) to deploy CreateX in tests.
     * @dev Uses vm.etch to place proxy bytecode at the expected addresses, ensuring Nox
     *      library calls work correctly in tests.
     */
    function deploy(address owner, address gateway) internal returns (NoxCompute noxCompute) {
        Vm vm = getVm();
        address noxComputeAddress = Nox.noxComputeContract();
        // Deploy NoxCompute implementation
        address noxComputeImplementation = address(new NoxCompute());

        // Deploy a temporary proxy to get its runtime bytecode
        address noxComputeProxyTemp = deployProxy(
            noxComputeImplementation,
            owner,
            vm.randomBytes(33)
        );

        // Etch the proxy bytecode at the NoxCompute address resolved by Nox
        vm.etch(noxComputeAddress, noxComputeProxyTemp.code);
        // Set the implementation slot
        vm.store(
            noxComputeAddress,
            IMPLEMENTATION_SLOT,
            bytes32(uint256(uint160(noxComputeImplementation)))
        );

        noxCompute = NoxCompute(noxComputeAddress);
        noxCompute.initialize(owner, vm.randomBytes(33));
        vm.prank(owner);
        noxCompute.setGateway(gateway);

        // Set labels
        vm.label(owner, "owner");
        vm.label(gateway, "gateway");
        vm.label(noxComputeAddress, "noxCompute");

        return noxCompute;
    }

    /**
     * Override storage to force allow the given account for the given handle.
     */
    function forceAllowPersistent(bytes32 handle, address account) internal {
        bytes32 slotLocation = _getAllowStorageSlot(handle, account);
        getVm().store(Nox.noxComputeContract(), slotLocation, bytes32(uint256(1)));
    }

    /**
     * Override storage to force disallow the given account for the given handle.
     */
    function forceDisallowPersistent(bytes32 handle, address account) internal {
        bytes32 slotLocation = _getAllowStorageSlot(handle, account);
        getVm().store(Nox.noxComputeContract(), slotLocation, bytes32(uint256(0)));
    }

    /**
     * Transient storage cannot be overridden from the outside so we allow the account
     * persistently, call allowTransient from the account to set the transient state,
     * then disallow persistently again to clean up.
     */
    function forceAllowTransient(bytes32 handle, address account) internal {
        Vm vm = getVm();
        forceAllowPersistent(handle, account);
        vm.startPrank(account);
        INoxCompute(Nox.noxComputeContract()).allowTransient(handle, account);
        vm.stopPrank();
        forceDisallowPersistent(handle, account);
        vm.assertTrue(
            INoxCompute(Nox.noxComputeContract()).isAllowed(handle, account),
            "Should be allowed transient"
        );
    }

    function deployProxy(
        address implementation,
        address owner,
        bytes memory kmsPublicKey
    ) internal returns (address) {
        bytes memory initData = abi.encodeCall(NoxCompute.initialize, (owner, kmsPublicKey));
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        return address(proxy);
    }

    function getVm() internal pure returns (Vm) {
        return Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    function _eip712DomainSeparator() private view returns (bytes32) {
        NoxCompute noxCompute = NoxCompute(Nox.noxComputeContract());
        (
            , // bytes1 fields
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            , // uint256[] memory extensions, // bytes32 salt

        ) = noxCompute.eip712Domain();
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    chainId,
                    verifyingContract
                )
            );
    }
    function _getAllowStorageSlot(bytes32 handle, address account) private pure returns (bytes32) {
        bytes32 adminsMappingStorageLocation = NOX_COMPUTE_STORAGE_LOCATION; // first variable.
        // mapping(bytes32 key1 => mapping(key2 => bool)) map;
        // slot = keccak256(abi.encode(key2, keccak256(abi.encode(key1, position of map))));
        bytes32 outerKeyStorageLocation = keccak256(
            abi.encode(handle, adminsMappingStorageLocation)
        );
        return keccak256(abi.encode(account, outerKeyStorageLocation));
    }
}
