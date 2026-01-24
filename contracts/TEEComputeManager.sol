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
        address gateway;
    }

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

    /**
     * Sets Gateway wallet address.
     * Only callable by the owner.
     * @param gatewayAddress New Gateway wallet address
     */
    function setGateway(address gatewayAddress) external onlyOwner {
        if (gatewayAddress == address(0)) {
            revert InvalidZeroAddress();
        }
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        $.gateway = gatewayAddress;
        emit GatewayUpdated(gatewayAddress);
    }

    /// @inheritdoc ITEEComputeManager
    function plaintextToEncrypted(uint256 value, TEEType teeType) external pure returns (bytes32) {
        // TODO
        value;
        teeType;
        return bytes32(uint256(0));
    }

    /// @inheritdoc ITEEComputeManager
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        uint256 supportedTypes = _numericTypesMask();
        TEEType leftHandOperandType = _verifyAndReturnType(leftHandOperand, supportedTypes);
        result = _binaryOp(
            Operators.teeAdd,
            leftHandOperand,
            rightHandOperand,
            leftHandOperandType
        );
        emit Add(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        uint256 supportedTypes = _numericTypesMask();
        TEEType leftHandOperandType = _verifyAndReturnType(leftHandOperand, supportedTypes);
        result = _binaryOp(
            Operators.teeSub,
            leftHandOperand,
            rightHandOperand,
            leftHandOperandType
        );
        emit Sub(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function div(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        if (rightHandOperand == 0) revert DivisionByZero();
        uint256 supportedTypes = _numericTypesMask();
        TEEType leftHandOperandType = _verifyAndReturnType(leftHandOperand, supportedTypes);
        result = _binaryOp(
            Operators.teeDiv,
            leftHandOperand,
            rightHandOperand,
            leftHandOperandType
        );
        emit Div(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /**
     * Validates that a handle provided by a user is:
     *   - of expected type
     *   - not expired (TODO)
     *   - issued for the correct ACL
     *   - issued for the correct owner
     *   - issued by the configured gateway (signed by the gateway wallet)
     * or reverts otherwise.
     *
     * Handle format:
     *    26 bytes          4 bytes     1 byte  1 byte
     * [0----------25]    [26-----29]    [30]    [31]
     *   Pre-handle         ChainId      Type   Version
     *
     * Proof format:
     *  20 bytes       20 bytes        32 bytes            65 bytes
     * [0-----19]    [20-----39]    [40--------71]    [72------------136]
     *   Owner           ACL           CreatedAt       EIP-712 signature
     *
     * @param handle handle id
     * @param owner The address of the handle owner
     * @param proof Proof data
     */
    function validateProof(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) public view {
        // TODO check chainId
        if (handle[30] != bytes1(uint8(teeType))) {
            revert InvalidProof(proof, "Handle type mismatch");
        }
        if (proof.length != 137) {
            revert InvalidProof(proof, "Invalid proof length");
        }
        address ownerInProof = address(bytes20(proof[0:20]));
        address aclInProof = address(bytes20(proof[20:40]));
        uint256 createdAt = uint256(bytes32(proof[40:72]));
        bytes calldata signature = proof[72:137];
        // TODO check handle type.
        // TODO add checks for `createdAt`.
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        if (aclInProof != $.acl) {
            revert InvalidProof(proof, "ACL mismatch");
        }
        if (ownerInProof != owner) {
            revert InvalidProof(proof, "Owner mismatch");
        }
        bytes32 eip712MessageHash = _hashTypedDataV4(
            keccak256(
                abi.encode(HANDLE_PROOF_TYPEHASH, handle, ownerInProof, aclInProof, createdAt)
            )
        );
        if (ECDSA.recover(eip712MessageHash, signature) != $.gateway) {
            revert InvalidProof(proof, "Invalid signature");
        }
        // TODO call ACL to allow here
    }

    /**
     * Returns the EIP-712 domain separator.
     */
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * Returns the ACL contract address.
     */
    function acl() external view returns (address) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        return $.acl;
    }

    /**
     * Returns the Gateway wallet address.
     */
    function gateway() external view returns (address) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        return $.gateway;
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

    function _numericTypesMask() private pure returns (uint256) {
        return
            (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
    }

    function _typeOf(bytes32 handle) private pure returns (TEEType) {
        return TEEType(uint8(handle[30]));
    }

    function _verifyAndReturnType(
        bytes32 handle,
        uint256 supportedTypes
    ) private pure returns (TEEType typeCt) {
        typeCt = _typeOf(handle);
        if ((1 << uint8(typeCt)) & supportedTypes == 0) revert UnsupportedType();
    }

    function _binaryOp(
        Operators op,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        TEEType resultType
    ) private returns (bytes32 result) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        IACL aclContract = IACL($.acl);

        if (!aclContract.isAllowed(leftHandOperand, msg.sender))
            revert ACLNotAllowed(leftHandOperand, msg.sender);
        if (!aclContract.isAllowed(rightHandOperand, msg.sender))
            revert ACLNotAllowed(rightHandOperand, msg.sender);

        if (_typeOf(leftHandOperand) != _typeOf(rightHandOperand)) revert IncompatibleTypes();

        result = keccak256(
            abi.encodePacked(op, leftHandOperand, rightHandOperand, $.acl, block.chainid)
        );
        result = _appendMetadataToPrehandle(result, resultType);
        aclContract.allowTransient(result, msg.sender);
    }

    function _appendMetadataToPrehandle(
        bytes32 prehandle,
        TEEType handleType
    ) private view returns (bytes32 result) {
        result = prehandle & 0xffffffffffffffffffffffffffffffffffffffffff0000000000000000000000;
        result = result | (bytes32(uint256(0xff)) << 80);
        result = result | (bytes32(uint256(uint64(block.chainid))) << 16);
        result = result | (bytes32(uint256(uint8(handleType))) << 8);
        result = result | bytes32(uint256(HANDLE_VERSION));
    }
}
