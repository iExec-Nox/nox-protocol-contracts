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
 * This contract is the main entry point to the TEE compute functionalities of the Nox protocol.
 * It's role includes:
 * - Managing the access control list (ACL) for encrypted handles
 * - Validating handle proofs issued by a trusted gateway
 * - Facilitating the conversion of plaintext values to encrypted values
 * - Triggering off-chain TEE computations through event emissions
 */
contract TEEComputeManager is
    ITEEComputeManager,
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable
{
    /// @custom:storage-location erc7201:nox.storage.TEEComputeManager
    struct TEEComputeManagerStorage {
        IACL acl;
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
        $.acl = IACL(newAcl);
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
    function plaintextToEncrypted(
        uint256 value,
        TEEType teeType
    ) external returns (bytes32 result) {
        uint256 supportedTypes = (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256)) +
            (1 << uint8(TEEType.Bool));
        if (((1 << uint8(teeType)) & supportedTypes) == 0) {
            revert UnsupportedType();
        }
        bytes32[] memory operands = new bytes32[](1);
        operands[0] = bytes32(value);
        result = _generateHandle(Operators.PlaintextToEncrypted, operands, teeType);
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        $.acl.allowTransient(result, msg.sender);
        emit PlaintextToEncrypted(msg.sender, value, teeType, result);
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
    ) public {
        bytes4 chainIdInHandle = bytes4(handle << (26 * 8));
        if (chainIdInHandle != bytes4(uint32(block.chainid))) {
            revert InvalidProof(proof, "Handle chain id mismatch");
        }
        if (_typeOf(handle) != teeType) {
            revert InvalidProof(proof, "Handle type mismatch");
        }
        if (proof.length != 137) {
            revert InvalidProof(proof, "Invalid proof length");
        }
        address ownerInProof = address(bytes20(proof[0:20]));
        address aclInProof = address(bytes20(proof[20:40]));
        uint256 createdAt = uint256(bytes32(proof[40:72]));
        bytes calldata signature = proof[72:137];
        // TODO add checks for `createdAt`.
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        if (aclInProof != address($.acl)) {
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
        // Give caller contract transient access to the handle.
        $.acl.allowTransient(handle, msg.sender);
    }

    /// @inheritdoc ITEEComputeManager
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeArithmeticOperation(Operators.Add, operands);
        emit Add(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeArithmeticOperation(Operators.Sub, operands);
        emit Sub(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function div(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeArithmeticOperation(Operators.Div, operands);
        emit Div(msg.sender, leftHandOperand, rightHandOperand, result);
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
        return address($.acl);
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
        internal
        pure
        returns (TEEComputeManagerStorage storage $)
    {
        assembly {
            $.slot := TEE_COMPUTE_MANAGER_STORAGE_LOCATION
        }
    }

    /**
     * Extracts the TEE type from a handle.
     * The type is stored at byte position 30 in the handle.
     * @param handle The handle to extract the type from
     * @return The TEEType encoded in the handle
     */
    function _typeOf(bytes32 handle) private pure returns (TEEType) {
        return TEEType(uint8(handle[30]));
    }

    /**
     * Executes a binary operation on N encrypted handles.
     * All operands must share the same type as the first operand, which also determines the result type.
     * Verifies ACL permissions for all operands, checks type compatibility,
     * generates a new result handle, and grants transient access to the caller.
     * @dev Reverts with ACLNotAllowed if caller lacks permission on any operand
     * @dev Reverts with IncompatibleTypes if operand types don't match
     *
     * @param operator The operator to apply (Add, Sub, Div, etc.)
     * @param operands Array of operand handles
     * @return result The resulting encrypted handle
     */
    function _executeArithmeticOperation(
        Operators operator,
        bytes32[] memory operands
    ) private returns (bytes32 result) {
        // Validate operand types are numeric
        uint256 supportedTypes = (1 << uint8(TEEType.Uint160)) +
            (1 << uint8(TEEType.Uint256)) +
            (1 << uint8(TEEType.Int256));
        TEEType resultType = _typeOf(operands[0]);
        if (((1 << uint8(resultType)) & supportedTypes) == 0) {
            revert UnsupportedType();
        }
        for (uint256 i = 1; i < operands.length; i++) {
            if (resultType != _typeOf(operands[i])) {
                revert IncompatibleTypes();
            }
        }
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        IACL aclContract = $.acl;
        for (uint256 i = 0; i < operands.length; i++) {
            if (!aclContract.isAllowed(operands[i], msg.sender)) {
                revert ACLNotAllowed(operands[i], msg.sender);
            }
        }
        result = _generateHandle(operator, operands, resultType);
        aclContract.allowTransient(result, msg.sender);
    }

    /**
     * Generates a complete handle from an operator and its operands.
     *
     * Pre-handle format:
     *   keccak256(abi.encodePacked(
     *       operator,        // Operator identifier (e.g., Add, Sub, Div)
     *       operands,        // Array of operand handles
     *       address(this),   // TEEComputeManager contract address
     *       msg.sender,      // Caller address
     *       block.timestamp, // Current block timestamp
     *       0                // For operations that return multiple outputs (can be 0 when needed)
     *   ))
     *
     * Handle format (32 bytes):
     *   [0-25]  : First 26 bytes of prehandle (truncated hash)
     *   [26-29] : Chain ID (4 bytes, from uint32)
     *   [30]    : TEE type
     *   [31]    : Handle version
     *
     * @param operator The operator to apply
     * @param operands Array of operand handles
     * @param handleType The TEE type to encode in the handle
     * @return result The complete handle with metadata appended
     */
    function _generateHandle(
        Operators operator,
        bytes32[] memory operands,
        TEEType handleType
    ) private view returns (bytes32 result) {
        result = keccak256(
            abi.encodePacked(
                operator,
                operands,
                address(this),
                msg.sender,
                block.timestamp,
                uint8(0)
            )
        );
        result = bytes32(
            abi.encodePacked(
                bytes26(result),
                bytes4(uint32(block.chainid)),
                bytes1(uint8(handleType)),
                bytes1(uint8(HANDLE_VERSION))
            )
        );
    }
}
