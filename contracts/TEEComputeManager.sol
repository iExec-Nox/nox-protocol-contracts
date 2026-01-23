// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ITEEComputeManager} from "./interfaces/ITEEComputeManager.sol";
import {IACL} from "./interfaces/IACL.sol";
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

    /// @notice Handle version for generated handles
    uint8 private constant HANDLE_VERSION = 0;

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
    function plaintextToEncrypted(uint256 pt, TEEType toType) external returns (bytes32 result) {
        uint256 supportedTypes = (1 << uint8(TEEType.Bool)) +
            (1 << uint8(TEEType.Address)) +
            (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));

        if ((1 << uint8(toType)) & supportedTypes == 0) revert UnsupportedType();
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        result = keccak256(
            abi.encodePacked(Operators.teePlaintextToEncrypted, pt, toType, $.acl, block.chainid)
        );
        result = _appendMetadataToPrehandle(result, toType);
        IACL($.acl).allowTransient(result, msg.sender);
        emit PlaintextToEncrypted(msg.sender, pt, uint8(toType), result);
    }

    /// @inheritdoc ITEEComputeManager
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        uint256 supportedTypes = (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
        TEEType lhsType = _verifyAndReturnType(leftHandOperand, supportedTypes);
        result = _binaryOp(Operators.teeAdd, leftHandOperand, rightHandOperand, lhsType);
        emit Add(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        uint256 supportedTypes = (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
        TEEType lhsType = _verifyAndReturnType(leftHandOperand, supportedTypes);
        result = _binaryOp(Operators.teeSub, leftHandOperand, rightHandOperand, lhsType);
        emit Sub(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function div(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        if (rightHandOperand == 0) revert DivisionByZero();
        uint256 supportedTypes = (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
        TEEType lhsType = _verifyAndReturnType(leftHandOperand, supportedTypes);
        result = _binaryOp(Operators.teeDiv, leftHandOperand, rightHandOperand, lhsType);
        emit Div(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function select(
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) external returns (bytes32 result) {
        uint256 supportedTypes = (1 << uint8(TEEType.Bool)) +
            (1 << uint8(TEEType.Address)) +
            (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
        _verifyAndReturnType(ifTrue, supportedTypes);
        result = _ternaryOp(Operators.teeSelect, condition, ifTrue, ifFalse);
        emit Select(msg.sender, condition, ifTrue, ifFalse, result);
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

    /**
     * @dev Extracts the type from a handle.
     * @param handle The handle to extract the type from.
     * @return typeCt The TEEType encoded in the handle.
     */
    function _typeOf(bytes32 handle) internal pure returns (TEEType typeCt) {
        typeCt = TEEType(uint8(handle[30]));
    }

    /**
     * @dev Verifies the handle type is supported and returns the type.
     * @param handle The handle to verify.
     * @param supportedTypes Bitmask of supported types.
     * @return typeCt The TEEType of the handle.
     */
    function _verifyAndReturnType(
        bytes32 handle,
        uint256 supportedTypes
    ) internal pure returns (TEEType typeCt) {
        typeCt = _typeOf(handle);
        if ((1 << uint8(typeCt)) & supportedTypes == 0) revert UnsupportedType();
    }

    /**
     * @dev Appends metadata to a pre-handle to create a full handle.
     * @param prehandle The pre-handle (hash) to append metadata to.
     * @param handleType The type to encode in the handle.
     * @return result The full handle with metadata.
     */
    function _appendMetadataToPrehandle(
        bytes32 prehandle,
        TEEType handleType
    ) internal view returns (bytes32 result) {
        /// @dev Clear bytes 21-31.
        result = prehandle & 0xffffffffffffffffffffffffffffffffffffffffff0000000000000000000000;
        /// @dev Set byte 21 to 0xff since the new handle comes from computation.
        result = result | (bytes32(uint256(0xff)) << 80);
        /// @dev chainId is cast to uint64 first to make sure it does not take more than 8 bytes before shifting.
        result = result | (bytes32(uint256(uint64(block.chainid))) << 16);
        /// @dev Insert handleType into byte 30.
        result = result | (bytes32(uint256(uint8(handleType))) << 8);
        /// @dev Insert HANDLE_VERSION into byte 31.
        result = result | bytes32(uint256(HANDLE_VERSION));
    }

    /**
     * @dev Executes a binary operation on two handles.
     * @param op The operator to apply.
     * @param lhs Left-hand side handle.
     * @param rhs Right-hand side handle.
     * @param resultType The type of the result handle.
     * @return result The resulting handle.
     */
    function _binaryOp(
        Operators op,
        bytes32 lhs,
        bytes32 rhs,
        TEEType resultType
    ) internal returns (bytes32 result) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        IACL aclContract = IACL($.acl);

        if (!aclContract.isAllowed(lhs, msg.sender)) revert ACLNotAllowed(lhs, msg.sender);
        if (!aclContract.isAllowed(rhs, msg.sender)) revert ACLNotAllowed(rhs, msg.sender);

        TEEType rhsType = _typeOf(rhs);
        TEEType lhsType = _typeOf(lhs);
        if (lhsType != rhsType) revert IncompatibleTypes();

        result = keccak256(abi.encodePacked(op, lhs, rhs, $.acl, block.chainid));
        result = _appendMetadataToPrehandle(result, resultType);
        aclContract.allowTransient(result, msg.sender);
    }

    /**
     * @dev Executes a ternary operation (select/if-then-else).
     * @param op The operator to apply.
     * @param control The control handle (must be Bool type).
     * @param ifTrue The handle to return if control is true.
     * @param ifFalse The handle to return if control is false.
     * @return result The resulting handle.
     */
    function _ternaryOp(
        Operators op,
        bytes32 control,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) internal returns (bytes32 result) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        IACL aclContract = IACL($.acl);

        if (!aclContract.isAllowed(control, msg.sender)) revert ACLNotAllowed(control, msg.sender);
        if (!aclContract.isAllowed(ifTrue, msg.sender)) revert ACLNotAllowed(ifTrue, msg.sender);
        if (!aclContract.isAllowed(ifFalse, msg.sender)) revert ACLNotAllowed(ifFalse, msg.sender);

        TEEType controlType = _typeOf(control);
        TEEType ifTrueType = _typeOf(ifTrue);
        TEEType ifFalseType = _typeOf(ifFalse);

        /// @dev control must be Bool
        if (controlType != TEEType.Bool) revert UnsupportedType();
        if (ifTrueType != ifFalseType) revert IncompatibleTypes();

        result = keccak256(abi.encodePacked(op, control, ifTrue, ifFalse, $.acl, block.chainid));
        result = _appendMetadataToPrehandle(result, ifTrueType);
        aclContract.allowTransient(result, msg.sender);
    }
}
