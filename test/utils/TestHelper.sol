// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Vm} from "forge-std/src/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TEEType} from "../../contracts/utils/TypeUtils.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";

library TestHelper {
    bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    // ERC1967 implementation slot
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant NOX_COMPUTE_STORAGE_LOCATION = bytes32(
        erc7201("nox.storage.NoxCompute")
    );

    /**
     * Returns the list of all currently supported TEE types.
     * @dev Independent test oracle: this list is EXPLICITLY hardcoded and must not be derived
     * from TypeUtils.isSupportedType to force manually updating tests when new types are added.
     */
    function allCurrentlySupportedTypes() internal pure returns (TEEType[] memory types) {
        types = new TEEType[](5);
        types[0] = TEEType.Bool;
        types[1] = TEEType.Uint16;
        types[2] = TEEType.Uint256;
        types[3] = TEEType.Int16;
        types[4] = TEEType.Int256;
    }

    function isCurrentlySupportedType(TEEType t) internal pure returns (bool) {
        TEEType[] memory supported = TestHelper.allCurrentlySupportedTypes();
        for (uint256 i = 0; i < supported.length; i++) {
            if (supported[i] == t) {
                return true;
            }
        }
        return false;
    }

    /**
     * Generates a deterministic unique handle with the given type.
     * @param teeType target type
     */
    function createHandle(TEEType teeType) internal returns (bytes32 handle) {
        return createHandle(block.chainid, teeType);
    }

    /**
     * Generates a deterministic unique handle with the given chain id and type.
     * The handle is created with isUniqueHandle=1 (confidential handle with ACL).
     * Uses a nonce-based counter instead of vm.randomBytes to remain gas-stats compatible.
     * @param chainId target chainId
     * @param teeType target type
     */
    function createHandle(uint256 chainId, TEEType teeType) internal returns (bytes32 handle) {
        return
            bytes32(
                abi.encodePacked(
                    bytes1(0x00), // Version
                    bytes4(uint32(chainId)), // ChainId
                    bytes1(uint8(teeType)), // Type
                    bytes1(0x01), // Attributes
                    bytes25(_nextNonce()) // Pre-handle
                )
            );
    }

    /**
     * Generates a deterministic public handle (isUniqueHandle=0) with the given type.
     * @param teeType target type
     */
    function createPublicHandle(TEEType teeType) internal returns (bytes32 handle) {
        return
            bytes32(
                abi.encodePacked(
                    bytes1(0x00), // Version
                    bytes4(uint32(block.chainid)), // ChainId
                    bytes1(uint8(teeType)), // Type
                    bytes1(0x00), // Attributes
                    bytes25(_nextNonce()) // Pre-handle
                )
            );
    }

    /**
     * Builds a valid proof for the given parameters, signed by the given private key.
     */
    function buildInputProof(
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
     * Builds a valid decryption proof for the given parameters, signed by the given private key.
     */
    function buildDecryptionProof(
        bytes32 handle,
        bytes memory decryptedResult,
        uint256 signerPrivateKey
    ) internal view returns (bytes memory) {
        Vm vm = getVm();
        NoxCompute noxCompute = NoxCompute(Nox.noxComputeContract());
        // DecryptionProof(bytes32 handle,bytes decryptedResult)
        bytes32 structHash = keccak256(
            abi.encode(noxCompute.DECRYPTION_PROOF_TYPEHASH(), handle, keccak256(decryptedResult))
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(_eip712DomainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(r, s, v, decryptedResult);
    }

    /**
     * @notice Deploys NoxCompute at the addresses resolved by Nox for the current chain.
     * @dev Uses vm.etch to place proxy bytecode at the expected addresses, ensuring Nox
     *      library calls work correctly in tests.
     */
    function deploy(
        address admin,
        address upgrader,
        address gateway,
        bytes memory kmsKey
    ) internal returns (NoxCompute noxCompute) {
        Vm vm = getVm();
        address noxComputeAddress = Nox.noxComputeContract();
        address noxComputeImplementation = address(newImplementationInstance());

        // Deploy a temporary proxy to get its runtime bytecode
        address noxComputeProxyTemp = deployProxy(
            noxComputeImplementation,
            admin,
            upgrader,
            kmsKey,
            gateway
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
        noxCompute.initialize(admin, upgrader, kmsKey, gateway);

        // Set labels
        vm.label(admin, "admin");
        if (upgrader != admin) vm.label(upgrader, "upgrader");
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
        address admin,
        address upgrader,
        bytes memory kmsPublicKey,
        address gateway
    ) internal returns (address) {
        bytes memory initData = abi.encodeCall(
            NoxCompute.initialize,
            (admin, upgrader, kmsPublicKey, gateway)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        return address(proxy);
    }

    /**
     * Deploy a new instance of the NoxCompute implementation contract.
     */
    function newImplementationInstance() internal returns (NoxCompute) {
        return new NoxCompute();
    }

    /**
     * Deploys a new random proxy instance of NoxCompute.
     */
    function newProxyInstance() internal returns (NoxCompute proxy) {
        address implementation = address(newImplementationInstance());
        bytes memory kmsPublicKey = abi.encodePacked(bytes1(0x02), keccak256("kms-pub-key"));
        address proxyAddress = deployProxy(
            implementation,
            address(this),
            address(this),
            kmsPublicKey,
            address(1)
        );
        proxy = NoxCompute(proxyAddress);
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
            ,

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

    /**
     * @dev Replaces `vm.randomBytes` which breaks --gas-stats replay.
     * Returns a nonce for deterministic pseudo-random generation. The nonce is constructed
     * as a hash of the contract address and a counter, which is incremented on each call.
     * This ensures that the nonce is unique by contract.
     */
    function _nextNonce() private returns (bytes32 nonce) {
        // keccak256("TestHelper.nonce");
        bytes32 slot = 0xbefe5b44130896a9b1467a27eab7dc5adf3c7fc9d513b1a12dc949e60d2a0139;
        uint256 counter;
        assembly {
            counter := sload(slot)
            sstore(slot, add(counter, 1))
        }
        nonce = keccak256(abi.encode(address(this), counter));
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
