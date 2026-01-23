// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ITEEComputeManager} from "./interfaces/ITEEComputeManager.sol";
import {TEEType} from "./shared/TEEType.sol";

/**
 * @title TEEComputeManager
 * @notice Manages TEE-based encrypted computations and handle generation
 */
contract TEEComputeManager is
    ITEEComputeManager,
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable
{
    /// @custom:storage-location erc7201:nox.storage.TEEComputeManager
    struct TEEComputeManagerStorage {
        address acl;
    }

    // keccak256(abi.encode(uint256(keccak256("nox.storage.TEEComputeManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_COMPUTE_MANAGER_STORAGE_LOCATION =
        0xc3e1031bc9fe6b2927aae1aa699e4b02aecc2dc8724a4333ac8dcd9db8c62b00;

    bytes32 public constant HANDLE_PROOF_TYPEHASH =
        keccak256("HandleProof(bytes32 handle,address owner,address acl,uint256 createdAt)");

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * Initializes the proxy contract state.
     * @param initialOwner Initial owner address
     */
    function initialize(address initialOwner) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(initialOwner);
        __EIP712_init("TEEComputeManager", "1");
    }

    /**
     * Sets a new ACL contract address.
     * Only callable by the owner.
     * @param newAcl New ACL contract address
     */
    function setAcl(address newAcl) external onlyOwner {
        if (newAcl == address(0)) {
            revert InvalidZeroAddress();
        }
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        $.acl = newAcl;
        emit ACLUpdated(newAcl);
    }

    /// @inheritdoc ITEEComputeManager
    function plaintextToEncrypted(uint256 pt, TEEType toType) external pure returns (bytes32) {
        // TODO
        pt;
        toType;
        return bytes32(0);
    }

    /// @inheritdoc ITEEComputeManager
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external pure returns (bytes32) {
        // TODO
        leftHandOperand;
        rightHandOperand;
        return bytes32(0);
    }

    /// @inheritdoc ITEEComputeManager
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external pure returns (bytes32) {
        // TODO
        leftHandOperand;
        rightHandOperand;
        return bytes32(0);
    }

    /// @inheritdoc ITEEComputeManager
    function div(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external pure returns (bytes32) {
        // TODO
        leftHandOperand;
        rightHandOperand;
        return bytes32(0);
    }

    /**
     * Validates a handle's ownership proof. Reverts if the proof is invalid.
     * Proof format:
     *    owner (20 bytes) || ACL (20 bytes) || createdAt (32 bytes) || EIP-712 signature (65 bytes)
     *
     * @param handle handle id
     * @param signer Expected signer address
     * @param proof Proof data
     */
    function validateProof(bytes32 handle, address signer, bytes calldata proof) public view {
        if (proof.length != 137) {
            revert InvalidProof(proof, "Invalid length");
        }
        address owner = address(bytes20(proof[0:20]));
        address proofAcl = address(bytes20(proof[20:40]));
        uint256 createdAt = uint256(bytes32(proof[40:72]));
        bytes calldata signature = proof[72:137];
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        if (proofAcl != $.acl) {
            revert InvalidProof(proof, "ACL mismatch");
        }
        // TODO add checks for `createdAt`.
        bytes32 eip712MessageHash = _hashTypedDataV4(
            keccak256(abi.encode(HANDLE_PROOF_TYPEHASH, handle, owner, proofAcl, createdAt))
        );
        if (ECDSA.recover(eip712MessageHash, signature) != signer) {
            revert InvalidProof(proof, "Signer mismatch");
        }
    }

    /**
     * Returns the configured ACL contract address.
     */
    function acl() external view returns (address) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        return $.acl;
    }

    /**
     * Authorizes contract upgrades only by the owner.
     */
    function _authorizeUpgrade(address /*newImplementation*/) internal override onlyOwner {}

    function _getTEEComputeManagerStorage()
        private
        pure
        returns (TEEComputeManagerStorage storage $)
    {
        assembly {
            $.slot := TEE_COMPUTE_MANAGER_STORAGE_LOCATION
        }
    }
}
