// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ITEEComputeManager} from "./interfaces/ITEEComputeManager.sol";
import {IACL} from "./interfaces/IACL.sol";
import {TEEType, TypeUtils, UnsupportedType} from "./shared/TypeUtils.sol";

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
        address gateway;
    }

    uint8 private constant HANDLE_VERSION = 0;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IACL public immutable ACL;

    // keccak256(abi.encode(uint256(keccak256("nox.storage.TEEComputeManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEE_COMPUTE_MANAGER_STORAGE_LOCATION =
        0xc3e1031bc9fe6b2927aae1aa699e4b02aecc2dc8724a4333ac8dcd9db8c62b00;
    bytes32 public constant HANDLE_PROOF_TYPEHASH =
        keccak256("HandleProof(bytes32 handle,address owner,address app,uint256 createdAt)");

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address acl_) {
        if (acl_ == address(0)) {
            revert InvalidZeroAddress();
        }
        ACL = IACL(acl_);
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
        TypeUtils.validateEncryptableType(teeType);
        bytes32[] memory operands = new bytes32[](1);
        operands[0] = bytes32(value);
        result = _generateHandle(Operator.PlaintextToEncrypted, operands, teeType);
        ACL.allowTransient(result, msg.sender);
        emit PlaintextToEncrypted(msg.sender, value, teeType, result);
    }

    /**
     * Validates that a handle provided by a user is:
     *   - of expected type
     *   - not expired (TODO)
     *   - issued for the correct app (caller)
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
     *   Owner           App           CreatedAt       EIP-712 signature
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
        if (TypeUtils.typeOf(handle) != teeType) {
            revert InvalidProof(proof, "Handle type mismatch");
        }
        if (proof.length != 137) {
            revert InvalidProof(proof, "Invalid proof length");
        }
        address ownerInProof = address(bytes20(proof[0:20]));
        address appInProof = address(bytes20(proof[20:40]));
        uint256 createdAt = uint256(bytes32(proof[40:72]));
        bytes calldata signature = proof[72:137];
        // TODO add checks for `createdAt`.
        if (appInProof != msg.sender) {
            revert InvalidProof(proof, "App mismatch");
        }
        if (ownerInProof != owner) {
            revert InvalidProof(proof, "Owner mismatch");
        }
        bytes32 eip712MessageHash = _hashTypedDataV4(
            keccak256(
                abi.encode(HANDLE_PROOF_TYPEHASH, handle, ownerInProof, appInProof, createdAt)
            )
        );
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        if (ECDSA.recover(eip712MessageHash, signature) != $.gateway) {
            revert InvalidProof(proof, "Invalid signature");
        }
        // Give caller contract transient access to the handle.
        ACL.allowTransient(handle, msg.sender);
    }

    /// @inheritdoc ITEEComputeManager
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        (, result) = _executeArithmeticOperation(Operator.Add, operands, false);
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
        (, result) = _executeArithmeticOperation(Operator.Sub, operands, false);
        emit Sub(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function div(bytes32 numerator, bytes32 denominator) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = numerator;
        operands[1] = denominator;
        (, result) = _executeArithmeticOperation(Operator.Div, operands, false);
        emit Div(msg.sender, numerator, denominator, result);
    }

    /// @inheritdoc ITEEComputeManager
    function mul(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        (, result) = _executeArithmeticOperation(Operator.Mul, operands, false);
        emit Mul(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function eq(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeComparisonOperation(Operator.Eq, operands);
        emit Eq(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function ne(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeComparisonOperation(Operator.Ne, operands);
        emit Ne(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function lt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeComparisonOperation(Operator.Lt, operands);
        emit Lt(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function le(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeComparisonOperation(Operator.Le, operands);
        emit Le(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function gt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeComparisonOperation(Operator.Gt, operands);
        emit Gt(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function ge(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        result = _executeComparisonOperation(Operator.Ge, operands);
        emit Ge(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc ITEEComputeManager
    function safeAdd(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        (success, result) = _executeArithmeticOperation(Operator.SafeAdd, operands, true);
        emit SafeAdd(msg.sender, leftHandOperand, rightHandOperand, success, result);
    }

    /// @inheritdoc ITEEComputeManager
    function safeSub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        (success, result) = _executeArithmeticOperation(Operator.SafeSub, operands, true);
        emit SafeSub(msg.sender, leftHandOperand, rightHandOperand, success, result);
    }

    /// @inheritdoc ITEEComputeManager
    function select(
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) external returns (bytes32 result) {
        if (TypeUtils.typeOf(condition) != TEEType.Bool) {
            revert UnsupportedType();
        }
        TEEType resultType = TypeUtils.typeOf(ifTrue);
        if (resultType != TypeUtils.typeOf(ifFalse)) {
            revert IncompatibleTypes();
        }
        //TODO: check if we need ACL.isAllowed(bytes32[] handles, address account)
        if (!ACL.isAllowed(condition, msg.sender)) {
            revert ACLNotAllowed(condition, msg.sender);
        }
        if (!ACL.isAllowed(ifTrue, msg.sender)) {
            revert ACLNotAllowed(ifTrue, msg.sender);
        }
        if (!ACL.isAllowed(ifFalse, msg.sender)) {
            revert ACLNotAllowed(ifFalse, msg.sender);
        }
        bytes32[] memory operands = new bytes32[](3);
        operands[0] = condition;
        operands[1] = ifTrue;
        operands[2] = ifFalse;
        result = _generateHandle(Operator.Select, operands, resultType);
        ACL.allowTransient(result, msg.sender);
        emit Select(msg.sender, condition, ifTrue, ifFalse, result);
    }

    /**
     * Returns the EIP-712 domain separator.
     */
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * Returns the Gateway wallet address.
     */
    function gateway() external view returns (address) {
        TEEComputeManagerStorage storage $ = _getTEEComputeManagerStorage();
        return $.gateway;
    }

    /// @inheritdoc ITEEComputeManager
    function isAllowed(bytes32 handle, address account) external view returns (bool) {
        return ACL.isAllowed(handle, account);
    }

    /// @inheritdoc ITEEComputeManager
    function isViewer(bytes32 handle, address viewer) external view returns (bool) {
        return ACL.isViewer(handle, viewer);
    }

    /// @inheritdoc ITEEComputeManager
    function isPubliclyDecryptable(bytes32 handle) external view returns (bool) {
        return ACL.isPubliclyDecryptable(handle);
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
     * Executes an arithmetic operation on N encrypted handles.
     * All operands must share the same type as the first operand, which also determines the result type.
     * Verifies ACL permissions for all operands, checks type compatibility,
     * generates result handle(s), and grants transient access to the caller.
     *
     * When `isSafeOperation` is true, generates an additional Bool success handle (outputIndex 1)
     * and the result handle at outputIndex 0, enabling overflow/underflow detection.
     *
     * @dev Reverts with ACLNotAllowed if caller lacks permission on any operand
     * @dev Reverts with IncompatibleTypes if operand types don't match
     *
     * @param operator The operator to apply (Add, Sub, Div, SafeAdd, SafeSub)
     * @param operands Array of operand handles
     * @param isSafeOperation Whether to generate a Bool success handle alongside the result
     * @return success The success flag handle (Bool type), bytes32(0) if not safe operation
     * @return result The resulting encrypted handle
     */
    function _executeArithmeticOperation(
        Operator operator,
        bytes32[] memory operands,
        bool isSafeOperation
    ) private returns (bytes32 success, bytes32 result) {
        TEEType resultType = TypeUtils.typeOf(operands[0]);
        TypeUtils.validateArithmeticType(resultType);
        for (uint256 i = 1; i < operands.length; i++) {
            if (resultType != TypeUtils.typeOf(operands[i])) {
                revert IncompatibleTypes();
            }
        }
        for (uint256 i = 0; i < operands.length; i++) {
            if (!ACL.isAllowed(operands[i], msg.sender)) {
                revert ACLNotAllowed(operands[i], msg.sender);
            }
        }
        result = _generateHandle(operator, operands, resultType);
        ACL.allowTransient(result, msg.sender);
        if (isSafeOperation) {
            success = _generateHandle(operator, operands, TEEType.Bool, 1);
            ACL.allowTransient(success, msg.sender);
        }
    }

    /**
     * Executes a comparison operation on two encrypted handles.
     * Both operands must share the same arithmetic type (Uint256 or Int256).
     * Verifies ACL permissions for all operands, checks type compatibility,
     * generates a Bool result handle, and grants transient access to the caller.
     *
     * @dev Reverts with ACLNotAllowed if caller lacks permission on any operand
     * @dev Reverts with IncompatibleTypes if operand types don't match
     *
     * @param operator The comparison operator to apply (Eq, Ne, Lt, Le, Gt, Ge)
     * @param operands Array of operand handles (must be 2)
     * @return result The resulting Bool handle
     */
    function _executeComparisonOperation(
        Operator operator,
        bytes32[] memory operands
    ) private returns (bytes32 result) {
        TEEType operandType = TypeUtils.typeOf(operands[0]);
        TypeUtils.validateArithmeticType(operandType);
        if (operandType != TypeUtils.typeOf(operands[1])) {
            revert IncompatibleTypes();
        }
        for (uint256 i = 0; i < operands.length; i++) {
            if (!ACL.isAllowed(operands[i], msg.sender)) {
                revert ACLNotAllowed(operands[i], msg.sender);
            }
        }
        result = _generateHandle(operator, operands, TEEType.Bool);
        ACL.allowTransient(result, msg.sender);
    }

    /**
     * @dev Alias for _generateHandle with outputIndex defaulting to 0.
     */
    function _generateHandle(
        Operator operator,
        bytes32[] memory operands,
        TEEType handleType
    ) private view returns (bytes32 result) {
        result = _generateHandle(operator, operands, handleType, 0);
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
     *       outputIndex      // For operations that return multiple outputs
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
     * @param outputIndex Index for operations returning multiple outputs
     * @return result The complete handle with metadata appended
     */
    function _generateHandle(
        Operator operator,
        bytes32[] memory operands,
        TEEType handleType,
        uint8 outputIndex
    ) private view returns (bytes32 result) {
        result = keccak256(
            abi.encodePacked(
                operator,
                operands,
                address(this),
                msg.sender,
                block.timestamp,
                outputIndex
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
