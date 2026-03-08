// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {INoxCompute} from "./interfaces/INoxCompute.sol";
import {TEEType, TypeUtils, HANDLE_ATTR_IS_PUBLIC_SCALAR, HANDLE_ATTR_IS_UNIQ_HANDLE} from "./shared/TypeUtils.sol";

/**
 * @title NoxCompute
 * This contract is the main entry point to the TEE compute functionalities of the Nox protocol.
 * It's role includes:
 * - Managing the access control list (ACL) for encrypted handles
 * - Validating handle proofs issued by a trusted gateway
 * - Facilitating the conversion of plaintext values to encrypted values
 * - Triggering off-chain TEE computations through event emissions
 *
 * @dev Using non upgradeable EIP712 is safe here because it has no storage and the config is saved
 * in immutable variables which should be enough here since we don't use multiple proxies with the
 * same implementation.
 */
contract NoxCompute is INoxCompute, UUPSUpgradeable, OwnableUpgradeable, EIP712 {
    /// @custom:storage-location erc7201:nox.storage.NoxCompute
    struct NoxComputeStorage {
        // An admin of a handle can:
        //  - use it as a computation input
        //  - decrypt its associated data off-chain
        //  - make it publicly decryptable
        //  - add other admins and viewers
        mapping(bytes32 handleId => mapping(address => bool)) admins;
        // A viewer of a handle can only decrypt its associated data off-chain.
        //TODO: Make viewer expirable
        mapping(bytes32 handleId => mapping(address => bool)) viewers;
        // Handles that are publicly decryptable
        mapping(bytes32 handle => bool) isPubliclyDecryptable;
        bytes kmsPublicKey;
        address gateway;
        uint256 proofExpirationDuration;
        // Incremented when all operands of an operation are non-unique public scalars,
        // ensuring the result handle remains unique even in that edge case.
        uint256 uniqSeedCounter;
    }

    uint8 private constant HANDLE_VERSION = 0;

    // keccak256(abi.encode(uint256(keccak256("nox.storage.NoxCompute")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NOX_COMPUTE_STORAGE_LOCATION =
        0x118a408ef9c0c38d6620cca4d300c2ce1c4f4cbcd93520940a6461e96acdcd00;
    bytes32 public constant HANDLE_PROOF_TYPEHASH =
        keccak256("HandleProof(bytes32 handle,address owner,address app,uint256 createdAt)");

    /**
     * Ensures the account address is not zero
     * @param account The address to validate
     */
    modifier notZeroAddress(address account) {
        require(account != address(0), InvalidZeroAddress());
        _;
    }

    /**
     * Ensures the sender is allowed to access the handle
     * @param handle The handle to check access for
     */
    modifier onlyAllowed(bytes32 handle) {
        require(isAllowed(handle, msg.sender), UnauthorizedSender(msg.sender));
        _;
    }

    /**
     * Ensures the handle is not a public scalar.
     * ACL mutations are forbidden on public scalar handles.
     * @param handle The handle to check
     */
    modifier notPublicScalar(bytes32 handle) {
        require(!TypeUtils.isPublicScalar(handle), PublicScalarACLForbidden());
        _;
    }

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() EIP712("NoxCompute", "1") {
        _disableInitializers();
    }

    /**
     * Initializes the proxy contract state.
     * @param initialOwner Initial owner address
     * @param kmsPublicKey_ KMS public key for ECIES encryption
     */
    function initialize(address initialOwner, bytes calldata kmsPublicKey_) public initializer {
        require(kmsPublicKey_.length != 0, InvalidEmptyBytes());
        __UUPSUpgradeable_init();
        __Ownable_init(initialOwner);
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = 1 hours;
        $.kmsPublicKey = kmsPublicKey_;
    }

    // ----------- ACL management -----------

    /// @inheritdoc INoxCompute
    function allow(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) notPublicScalar(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.admins[handle][account] = true;
        emit Allowed(msg.sender, account, handle);
    }

    /**
     * @inheritdoc INoxCompute
     * @dev To grant transient access, the caller must already have permission on `handle`.
     *      Transient access only lasts for the current transaction. It is the responsibility
     *      of the application contract to convert this into persistent access via `allow()`
     *      if needed.
     */
    function allowTransient(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) notPublicScalar(handle) onlyAllowed(handle) {
        _allowTransient(handle, account);
    }

    /// @inheritdoc INoxCompute
    function cleanTransientStorage() external override {
        assembly {
            let length := tload(0)
            tstore(0, 0)
            let lengthPlusOne := add(length, 1)
            for {
                let i := 1
            } lt(i, lengthPlusOne) {
                i := add(i, 1)
            } {
                let handle := tload(i)
                tstore(i, 0)
                tstore(handle, 0)
            }
        }
    }

    /// @inheritdoc INoxCompute
    function isAllowed(bytes32 handle, address account) public view override returns (bool) {
        // Public scalar handles are accessible by everyone — no ACL required.
        // Then read transient authorization to save gas on unnecessary storage reads.
        return TypeUtils.isPublicScalar(handle) || _isAllowedTransient(handle, account) || _isAllowedPersistent(handle, account);
    }

    /// @inheritdoc INoxCompute
    function validateAllowedForAll(address account, bytes32[] memory handles) public view override {
        for (uint256 i = 0; i < handles.length; i++) {
            if (!isAllowed(handles[i], account)) {
                revert NotAllowed(handles[i], account);
            }
        }
    }

    /// @inheritdoc INoxCompute
    function addViewer(
        bytes32 handle,
        address viewer
    ) external override notZeroAddress(viewer) notPublicScalar(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.viewers[handle][viewer] = true;
        emit ViewerAdded(msg.sender, viewer, handle);
    }

    /// @inheritdoc INoxCompute
    function isViewer(bytes32 handle, address viewer) external view override returns (bool) {
        // Public scalar handles are viewable by everyone — no ACL required.
        if (TypeUtils.isPublicScalar(handle)) return true;
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return
            $.isPubliclyDecryptable[handle] ||
            $.viewers[handle][viewer] ||
            $.admins[handle][viewer];
    }

    /// @inheritdoc INoxCompute
    function allowPublicDecryption(bytes32 handle) external override notPublicScalar(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.isPubliclyDecryptable[handle] = true;
        emit MarkedAsPubliclyDecryptable(msg.sender, handle);
    }

    /// @inheritdoc INoxCompute
    function isPubliclyDecryptable(bytes32 handle) external view override returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.isPubliclyDecryptable[handle];
    }

    /**
     * Grants transient access to a handle for an account. This function does not do any
     * checks and should be used with caution.
     * This function is used in two scenarios:
     *   - For handles generated off-chain by the Handle Gateway, once the proof has been verified
     *   - For handles resulting from on-chain operations, where the caller naturally inherits
     *     rights on the output handle
     * @param handle Handle identifier
     * @param account Address of the account
     */
    function _allowTransient(bytes32 handle, address account) private {
        // Public scalar handles are accessible by everyone — skip transient write.
        if (TypeUtils.isPublicScalar(handle)) {
            return;
        }
        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            tstore(key, 1)
            let length := tload(0)
            let lengthPlusOne := add(length, 1)
            tstore(lengthPlusOne, key)
            tstore(0, lengthPlusOne)
        }
    }

    /**
     * Check if an address has transient access to handle.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Returns `true` if the address has transient access to a handle and `false` otherwise.
     */
    function _isAllowedTransient(bytes32 handle, address account) private view returns (bool) {
        // Public scalar handles are accessible by everyone — skip transient read.
        if (TypeUtils.isPublicScalar(handle)) {
            return true;
        }

        bool isAllowedTransient_;
        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            isAllowedTransient_ := tload(key)
        }
        return isAllowedTransient_;
    }

    /**
     * Check if an address has persistent access to handle.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Returns `true` if the address has persistent access to a handle and `false` otherwise.
     */
    function _isAllowedPersistent(bytes32 handle, address account) private view returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.admins[handle][account];
    }

    // ----------- Compute functions -----------

    /// @inheritdoc INoxCompute
    function wrapPublicScalar(
        bytes32 value,
        TEEType teeType
    ) external returns (bytes32 result) {
        result = _generatePublicScalarHandle(value, teeType, 0);
        emit WrapPublicScalar(msg.sender, value, teeType, result);
    }

    /// @inheritdoc INoxCompute
    function generatePublicScalarFromUniqueSeed(
        bytes32 value,
        TEEType teeType,
        uint256 uniqSeed
    ) external returns (bytes32 result) {
        result = _generatePublicScalarHandle(value, teeType, uniqSeed);
        emit WrapPublicScalar(msg.sender, value, teeType, result);
    }

    /// @inheritdoc INoxCompute
    function isPublicScalar(bytes32 handle) external pure override returns (bool) {
        return TypeUtils.isPublicScalar(handle);
    }

    /**
     * Validates that a handle provided by a user is:
     *   - of expected type
     *   - not expired
     *   - issued for the correct app (caller)
     *   - issued for the correct owner
     *   - issued by the configured gateway (signed by the gateway wallet)
     * or reverts otherwise.
     *
     * Handle format:
     *      25 bytes         4 bytes   1 byte   1 byte   1 byte
     * [0-----------24]   [25----28]    [29]     [30]     [31]
     *    Pre-handle        ChainId     Type     Attrs   Version
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
        bytes4 chainIdInHandle = bytes4(handle << (25 * 8));
        require(
            chainIdInHandle == bytes4(uint32(block.chainid)),
            InvalidProof(proof, "Handle chain id mismatch")
        );
        require(TypeUtils.typeOf(handle) == teeType, InvalidProof(proof, "Handle type mismatch"));
        require(proof.length == 137, InvalidProof(proof, "Invalid proof length"));
        address ownerInProof = address(bytes20(proof[0:20]));
        address appInProof = address(bytes20(proof[20:40]));
        uint256 createdAt = uint256(bytes32(proof[40:72]));
        bytes calldata signature = proof[72:137];
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require(
            block.timestamp <= createdAt + $.proofExpirationDuration,
            InvalidProof(proof, "Proof expired")
        );
        require(appInProof == msg.sender, InvalidProof(proof, "App mismatch"));
        require(ownerInProof == owner, InvalidProof(proof, "Owner mismatch"));
        bytes32 eip712MessageHash = _hashTypedDataV4(
            keccak256(
                abi.encode(HANDLE_PROOF_TYPEHASH, handle, ownerInProof, appInProof, createdAt)
            )
        );
        require(
            ECDSA.recover(eip712MessageHash, signature) == $.gateway,
            InvalidProof(proof, "Invalid signature")
        );
        // Give caller contract transient access to the handle.
        _allowTransient(handle, msg.sender);
    }

    /// @inheritdoc INoxCompute
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

    /// @inheritdoc INoxCompute
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

    /// @inheritdoc INoxCompute
    function div(bytes32 numerator, bytes32 denominator) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = numerator;
        operands[1] = denominator;
        (, result) = _executeArithmeticOperation(Operator.Div, operands, false);
        emit Div(msg.sender, numerator, denominator, result);
    }

    /// @inheritdoc INoxCompute
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

    /// @inheritdoc INoxCompute
    function eq(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        result = _executeComparisonOperation(Operator.Eq, leftHandOperand, rightHandOperand);
        emit Eq(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc INoxCompute
    function ne(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        result = _executeComparisonOperation(Operator.Ne, leftHandOperand, rightHandOperand);
        emit Ne(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc INoxCompute
    function lt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        result = _executeComparisonOperation(Operator.Lt, leftHandOperand, rightHandOperand);
        emit Lt(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc INoxCompute
    function le(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        result = _executeComparisonOperation(Operator.Le, leftHandOperand, rightHandOperand);
        emit Le(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc INoxCompute
    function gt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        result = _executeComparisonOperation(Operator.Gt, leftHandOperand, rightHandOperand);
        emit Gt(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc INoxCompute
    function ge(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        result = _executeComparisonOperation(Operator.Ge, leftHandOperand, rightHandOperand);
        emit Ge(msg.sender, leftHandOperand, rightHandOperand, result);
    }

    /// @inheritdoc INoxCompute
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

    /// @inheritdoc INoxCompute
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

    /// @inheritdoc INoxCompute
    function safeMul(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        (success, result) = _executeArithmeticOperation(Operator.SafeMul, operands, true);
        emit SafeMul(msg.sender, leftHandOperand, rightHandOperand, success, result);
    }

    /// @inheritdoc INoxCompute
    function safeDiv(
        bytes32 numerator,
        bytes32 denominator
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = numerator;
        operands[1] = denominator;
        (success, result) = _executeArithmeticOperation(Operator.SafeDiv, operands, true);
        emit SafeDiv(msg.sender, numerator, denominator, success, result);
    }

    /// @inheritdoc INoxCompute
    function select(
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) external returns (bytes32 result) {
        require(TypeUtils.typeOf(condition) == TEEType.Bool, UnsupportedType());
        TEEType resultType = TypeUtils.typeOf(ifTrue);
        require(resultType == TypeUtils.typeOf(ifFalse), IncompatibleTypes());
        bytes32[] memory operands = new bytes32[](3);
        operands[0] = condition;
        operands[1] = ifTrue;
        operands[2] = ifFalse;
        validateAllowedForAll(msg.sender, operands);
        uint256 uniqSeed = _generateHandleUniqueSeed(operands);
        result = _generateHandle(Operator.Select, operands, resultType, uniqSeed, 0);
        _allowTransient(result, msg.sender);
        emit Select(msg.sender, condition, ifTrue, ifFalse, result);
    }

    /// @inheritdoc INoxCompute
    function transfer(
        bytes32 balanceFrom,
        bytes32 balanceTo,
        bytes32 amount
    ) external returns (bytes32 success, bytes32 newBalanceFrom, bytes32 newBalanceTo) {
        bytes32[] memory operands = new bytes32[](3);
        operands[0] = balanceFrom;
        operands[1] = balanceTo;
        operands[2] = amount;
        (success, newBalanceFrom, newBalanceTo) = _executeCompositeOperation(
            Operator.Transfer,
            operands
        );
        emit Transfer(
            msg.sender,
            balanceFrom,
            balanceTo,
            amount,
            success,
            newBalanceFrom,
            newBalanceTo
        );
    }

    /// @inheritdoc INoxCompute
    function mint(
        bytes32 balanceTo,
        bytes32 amount,
        bytes32 totalSupply
    ) external returns (bytes32 success, bytes32 newBalanceTo, bytes32 newTotalSupply) {
        bytes32[] memory operands = new bytes32[](3);
        operands[0] = balanceTo;
        operands[1] = amount;
        operands[2] = totalSupply;
        (success, newBalanceTo, newTotalSupply) = _executeCompositeOperation(
            Operator.Mint,
            operands
        );
        emit Mint(
            msg.sender,
            balanceTo,
            amount,
            totalSupply,
            success,
            newBalanceTo,
            newTotalSupply
        );
    }

    /// @inheritdoc INoxCompute
    function burn(
        bytes32 balanceFrom,
        bytes32 amount,
        bytes32 totalSupply
    ) external returns (bytes32 success, bytes32 newBalanceFrom, bytes32 newTotalSupply) {
        bytes32[] memory operands = new bytes32[](3);
        operands[0] = balanceFrom;
        operands[1] = amount;
        operands[2] = totalSupply;
        (success, newBalanceFrom, newTotalSupply) = _executeCompositeOperation(
            Operator.Burn,
            operands
        );
        emit Burn(
            msg.sender,
            balanceFrom,
            amount,
            totalSupply,
            success,
            newBalanceFrom,
            newTotalSupply
        );
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
     * @dev Reverts with NotAllowed if caller lacks permission on any operand
     * @dev Reverts with IncompatibleTypes if operand types don't match
     *
     * @param operator The operator to apply
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
        validateAllowedForAll(msg.sender, operands);
        uint256 uniqSeed = _generateHandleUniqueSeed(operands);
        result = _generateHandle(operator, operands, resultType, uniqSeed, 0);
        _allowTransient(result, msg.sender);
        if (isSafeOperation) {
            success = _generateHandle(operator, operands, TEEType.Bool, uniqSeed, 1);
            _allowTransient(success, msg.sender);
        }
    }

    /**
     * Executes a comparison operation on two encrypted handles.
     * Both operands must share the same arithmetic type.
     * Verifies ACL permissions for both operands, checks type compatibility,
     * generates a Bool result handle, and grants transient access to the caller.
     *
     * @dev Reverts with NotAllowed if caller lacks permission on any operand
     * @dev Reverts with IncompatibleTypes if operand types don't match
     *
     * @param operator The comparison operator to apply
     * @param leftOperand Left-hand side operand handle
     * @param rightOperand Right-hand side operand handle
     * @return result The resulting Bool handle
     */
    function _executeComparisonOperation(
        Operator operator,
        bytes32 leftOperand,
        bytes32 rightOperand
    ) private returns (bytes32 result) {
        TEEType operandType = TypeUtils.typeOf(leftOperand);
        TypeUtils.validateArithmeticType(operandType);
        require(TypeUtils.typeOf(rightOperand) == operandType, IncompatibleTypes());
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftOperand;
        operands[1] = rightOperand;
        validateAllowedForAll(msg.sender, operands);
        uint256 uniqSeed = _generateHandleUniqueSeed(operands);
        result = _generateHandle(operator, operands, TEEType.Bool, uniqSeed, 0);
        _allowTransient(result, msg.sender);
    }

    /**
     * Executes a composite operation on 3 encrypted handles (e.g. transfer, mint, burn).
     * All operands must share the same arithmetic type.
     * Generates 3 output handles: a Bool success flag and two result handles of the input type.
     *
     * @param operator The operator to apply
     * @param operands Array of 3 operand handles
     * @return success The success flag handle (Bool type)
     * @return result1 First result handle
     * @return result2 Second result handle
     */
    function _executeCompositeOperation(
        Operator operator,
        bytes32[] memory operands
    ) private returns (bytes32 success, bytes32 result1, bytes32 result2) {
        TEEType resultType = TypeUtils.typeOf(operands[0]);
        TypeUtils.validateArithmeticType(resultType);
        for (uint256 i = 1; i < operands.length; i++) {
            if (resultType != TypeUtils.typeOf(operands[i])) {
                revert IncompatibleTypes();
            }
        }
        validateAllowedForAll(msg.sender, operands);
        uint256 uniqSeed = _generateHandleUniqueSeed(operands);
        success = _generateHandle(operator, operands, TEEType.Bool, uniqSeed, 0);
        result1 = _generateHandle(operator, operands, resultType, uniqSeed, 1);
        result2 = _generateHandle(operator, operands, resultType, uniqSeed, 2);
        _allowTransient(success, msg.sender);
        _allowTransient(result1, msg.sender);
        _allowTransient(result2, msg.sender);
    }

    /**
     * Generates a complete confidential result handle from an operator and its operands.
     * Result handles are always unique (isUniqHandle=1) and never public scalars (isPublicScalar=0).
     *
     * Pre-handle format:
     *   keccak256(abi.encode(
     *       operator,        // Operator identifier (e.g., Add, Sub, Div)
     *       operands,        // Array of operand handles
     *       address(this),   // NoxCompute contract address
     *       uniqSeed,        // Non-zero only when all operands are non-unique public scalars
     *       outputIndex      // For operations that return multiple outputs, avoiding the gas costs to generate several uniqSeeds
     *   ))
     *
     * Handle format (32 bytes):
     *   [0-24]  : First 25 bytes of preHandle (truncated hash)
     *   [25-28] : Chain ID (4 bytes, from uint32)
     *   [29]    : TEE type
     *   [30]    : Attributes byte (bit 0: isPublicScalar, bit 1: isUniqHandle)
     *   [31]    : Handle version
     *
     * @param operator The operator to apply
     * @param operands Array of operand handles
     * @param handleType The TEE type to encode in the handle
     * @param outputIndex Index for operations returning multiple outputs
     * @param uniqSeed Counter value from _generateHandleUniqueSeed; 0 in the common case
     * @return result The complete handle with metadata appended
     */
    function _generateHandle(
        Operator operator,
        bytes32[] memory operands,
        TEEType handleType,
        uint256 uniqSeed,
        uint8 outputIndex
    ) private view returns (bytes32 result) {
        result = keccak256(
            abi.encode(operator, operands, address(this), uniqSeed, outputIndex)
        );
        // Keep only the leftmost 25 bytes of the hash and append handle metadata.
        result = result & 0xffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000;
        result = result | (bytes32(bytes4(uint32(block.chainid))) >> (25 * 8));
        result = result | (bytes32(bytes1(uint8(handleType))) >> (29 * 8));
        result = result | (bytes32(bytes1(HANDLE_ATTR_IS_UNIQ_HANDLE)) >> (30 * 8));
        result = result | (bytes32(bytes1(uint8(HANDLE_VERSION))) >> (31 * 8));
    }

    /**
     * Returns a non-zero seed to use in handle generation when all operands are non-unique
     * handles like for public scalars (isUniqHandle=0). 
     * Increments a persistent counter in that case. This is used to ensure that the result handle
     * is unique even if all operands are public scalars.
     * 
     * Returns 0 immediately (no storage access) if any operand has isUniqHandle=1,
     * since uniqueness is already guaranteed by that operand.
     *
     * Gas cost:
     *   - Common case (any unique operand): ~21 gas/operand, no SLOAD/SSTORE
     *   - Edge case (all public scalars): ~5000 gas for 1 SLOAD + 1 SSTORE
     *
     * @param operands The operation input handles
     * @return seed 0 if any operand is unique, otherwise an incremented counter value
     */
    function _generateHandleUniqueSeed(bytes32[] memory operands) private returns (uint256 seed) {
        unchecked {
            uint256 len = operands.length;
            for (uint256 i; i < len; ++i) {
                if (TypeUtils.isUniqHandle(operands[i])) {
                    return 0;
                }
            }
            NoxComputeStorage storage $ = _getNoxComputeStorage();
            return ++$.uniqSeedCounter;
        }
    }

    /**
     * Generates a unique public scalar handle (isPublicScalar=1, isUniqHandle=1).
     * Used by generatePublicScalarFromUniqueSeed when the caller supplies a uniqSeed.
     * Salt = (address(this), chainId, handleType, value, uniqSeed).
     */
    function _generatePublicScalarHandle(
        bytes32 value,
        TEEType handleType,
        uint256 uniqSeed
    ) private view returns (bytes32 result) {
        result = keccak256(abi.encode(address(this), block.chainid, handleType, value, uniqSeed));
        // Keep only the leftmost 25 bytes of the hash and append handle metadata.
        result = result & 0xffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000;
        result = result | (bytes32(bytes4(uint32(block.chainid))) >> (25 * 8));
        result = result | (bytes32(bytes1(uint8(handleType))) >> (29 * 8));
        // isUniqHandle=1 when a uniqSeed was provided, 0 otherwise
        uint8 attrs = uniqSeed != 0
            ? HANDLE_ATTR_IS_PUBLIC_SCALAR | HANDLE_ATTR_IS_UNIQ_HANDLE
            : HANDLE_ATTR_IS_PUBLIC_SCALAR;
        result = result | (bytes32(bytes1(attrs)) >> (30 * 8));
        result = result | (bytes32(bytes1(uint8(HANDLE_VERSION))) >> (31 * 8));
    }

    // ----------- Admin functions ----------

    /**
     * Sets the KMS public key used for ECIES encryption.
     * Only callable by the owner.
     * @param newKmsPublicKey Compressed SEC1 secp256k1 public key (33 bytes)
     */
    function setKmsPublicKey(bytes calldata newKmsPublicKey) external onlyOwner {
        require(newKmsPublicKey.length != 0, InvalidEmptyBytes());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.kmsPublicKey = newKmsPublicKey;
        emit KmsPublicKeyUpdated(newKmsPublicKey);
    }

    /**
     * Sets Gateway wallet address.
     * Only callable by the owner.
     * @param gatewayAddress New Gateway wallet address
     */
    function setGateway(address gatewayAddress) external onlyOwner {
        require(gatewayAddress != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.gateway = gatewayAddress;
        emit GatewayUpdated(gatewayAddress);
    }

    /**
     * Sets the proof expiration duration.
     * Only callable by the owner.
     * @param newDuration New expiration duration in seconds
     */
    function setProofExpirationDuration(uint256 newDuration) external onlyOwner {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = newDuration;
        emit ProofExpirationDurationUpdated(newDuration);
    }

    /**
     * Returns the KMS public key used for ECIES encryption.
     */
    function kmsPublicKey() external view returns (bytes memory) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.kmsPublicKey;
    }

    /**
     * Returns the Gateway wallet address.
     */
    function gateway() external view returns (address) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.gateway;
    }

    /**
     * Returns the proof expiration duration in seconds.
     */
    function proofExpirationDuration() external view returns (uint256) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.proofExpirationDuration;
    }

    /**
     * Authorizes contract upgrades only by the owner.
     */
    function _authorizeUpgrade(address /*newImplementation*/) internal override onlyOwner {}

    function _getNoxComputeStorage() internal pure returns (NoxComputeStorage storage $) {
        assembly {
            $.slot := NOX_COMPUTE_STORAGE_LOCATION
        }
    }
}
