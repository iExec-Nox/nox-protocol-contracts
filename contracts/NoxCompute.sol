// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {INoxCompute} from "./interfaces/INoxCompute.sol";
import {TEEType, TypeUtils} from "./shared/TypeUtils.sol";

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
        // Counter used to guarantee handle uniqueness when all operands are public handles
        uint256 uniqueSeedCounter;
    }

    uint8 private constant HANDLE_VERSION = 0;

    // keccak256(abi.encode(uint256(keccak256("nox.storage.NoxCompute")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NOX_COMPUTE_STORAGE_LOCATION =
        0x118a408ef9c0c38d6620cca4d300c2ce1c4f4cbcd93520940a6461e96acdcd00;
    bytes32 public constant HANDLE_PROOF_TYPEHASH =
        keccak256("HandleProof(bytes32 handle,address owner,address app,uint256 createdAt)");
    bytes32 public constant DECRYPTION_PROOF_TYPEHASH =
        keccak256("DecryptionProof(bytes32 handle,bytes decryptedResult)");

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
     * Prevents ACL mutations on public handles.
     * Applied before onlyAllowed to avoid unnecessary storage reads.
     * @param handle The handle to check
     */
    modifier notPublicHandle(bytes32 handle) {
        require(!TypeUtils.isPublicHandle(handle), PublicHandleACLForbidden());
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
    ) external override notZeroAddress(account) notPublicHandle(handle) onlyAllowed(handle) {
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
    ) external override notZeroAddress(account) notPublicHandle(handle) onlyAllowed(handle) {
        _allowTransient(handle, account);
    }

    /// @inheritdoc INoxCompute
    function disallowTransient(
        bytes32 handle,
        address account
    ) external override notZeroAddress(account) notPublicHandle(handle) onlyAllowed(handle) {
        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            tstore(key, 0)
        }
    }

    /// @inheritdoc INoxCompute
    function isAllowed(bytes32 handle, address account) public view override returns (bool) {
        return
            TypeUtils.isPublicHandle(handle) ||
            _isAllowedTransient(handle, account) ||
            _isAllowedPersistent(handle, account);
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
    ) external override notZeroAddress(viewer) notPublicHandle(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.viewers[handle][viewer] = true;
        emit ViewerAdded(msg.sender, viewer, handle);
    }

    /// @inheritdoc INoxCompute
    function isViewer(bytes32 handle, address viewer) external view override returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return
            TypeUtils.isPublicHandle(handle) ||
            $.isPubliclyDecryptable[handle] ||
            $.viewers[handle][viewer] ||
            $.admins[handle][viewer];
    }

    /// @inheritdoc INoxCompute
    function allowPublicDecryption(
        bytes32 handle
    ) external override notPublicHandle(handle) onlyAllowed(handle) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.isPubliclyDecryptable[handle] = true;
        emit MarkedAsPubliclyDecryptable(msg.sender, handle);
    }

    /// @inheritdoc INoxCompute
    function isPubliclyDecryptable(bytes32 handle) external view override returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return TypeUtils.isPublicHandle(handle) || $.isPubliclyDecryptable[handle];
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
        // Public handles don't need ACL; skip silently to save gas.
        if (TypeUtils.isPublicHandle(handle)) {
            return;
        }
        bytes32 key = keccak256(abi.encodePacked(handle, account));
        assembly {
            tstore(key, 1)
        }
    }

    /**
     * Check if an address has transient access to handle.
     * @param handle Handle.
     * @param account Address of the account.
     * @return Returns `true` if the address has transient access to a handle and `false` otherwise.
     */
    function _isAllowedTransient(bytes32 handle, address account) private view returns (bool) {
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
    function wrapAsPublicHandle(bytes32 value, TEEType teeType) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](1);
        operands[0] = value;
        // Deterministic handle: same (value, type) always produces the same handle
        result = _generatePublicHandle(Operator.WrapAsPublicHandle, operands, teeType);
        _allowTransient(result, msg.sender);
        emit WrapAsPublicHandle(msg.sender, value, teeType, result);
    }

    /// @inheritdoc INoxCompute
    function validateInputProof(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) public {
        bytes4 chainIdInHandle = bytes4(handle << (1 * 8));
        require(
            chainIdInHandle == bytes4(uint32(block.chainid)),
            InvalidProof(proof, "Handle chain id mismatch")
        );
        require(TypeUtils.typeOf(handle) == teeType, InvalidProof(proof, "Handle type mismatch"));
        require(proof.length == 137, InvalidProof(proof, "Invalid proof length"));
        address ownerInProof;
        address appInProof;
        uint256 createdAt;
        assembly {
            ownerInProof := shr(96, calldataload(proof.offset))
            appInProof := shr(96, calldataload(add(proof.offset, 20)))
            createdAt := calldataload(add(proof.offset, 40))
        }
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
    function validateDecryptionProof(
        bytes32 handle,
        bytes calldata decryptionProof
    ) external view returns (bytes memory) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require(
            decryptionProof.length >= 65 + 32,
            InvalidProof(decryptionProof, "Proof too short")
        );
        bytes calldata decryptedResult = decryptionProof[65:];
        bytes32 eip712MessageHash = _hashTypedDataV4(
            keccak256(abi.encode(DECRYPTION_PROOF_TYPEHASH, handle, keccak256(decryptedResult)))
        );
        require(
            ECDSA.recoverCalldata(eip712MessageHash, decryptionProof[:65]) == $.gateway,
            InvalidProof(decryptionProof, "Invalid signature")
        );
        return decryptedResult;
    }

    /// @inheritdoc INoxCompute
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        (, result) = _executeArithmeticOperation(Operator.Add, operands, false);
        emit Add(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        (, result) = _executeArithmeticOperation(Operator.Sub, operands, false);
        emit Sub(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function div(bytes32 numerator, bytes32 denominator) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = numerator;
        operands[1] = denominator;
        TypeUtils.resolveNullOperands(operands);
        (, result) = _executeArithmeticOperation(Operator.Div, operands, false);
        emit Div(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function mul(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        (, result) = _executeArithmeticOperation(Operator.Mul, operands, false);
        emit Mul(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function eq(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        result = _executeComparisonOperation(Operator.Eq, operands);
        emit Eq(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function ne(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        result = _executeComparisonOperation(Operator.Ne, operands);
        emit Ne(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function lt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        result = _executeComparisonOperation(Operator.Lt, operands);
        emit Lt(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function le(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        result = _executeComparisonOperation(Operator.Le, operands);
        emit Le(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function gt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        result = _executeComparisonOperation(Operator.Gt, operands);
        emit Gt(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function ge(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        result = _executeComparisonOperation(Operator.Ge, operands);
        emit Ge(msg.sender, operands[0], operands[1], result);
    }

    /// @inheritdoc INoxCompute
    function safeAdd(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        (success, result) = _executeArithmeticOperation(Operator.SafeAdd, operands, true);
        emit SafeAdd(msg.sender, operands[0], operands[1], success, result);
    }

    /// @inheritdoc INoxCompute
    function safeSub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        (success, result) = _executeArithmeticOperation(Operator.SafeSub, operands, true);
        emit SafeSub(msg.sender, operands[0], operands[1], success, result);
    }

    /// @inheritdoc INoxCompute
    function safeMul(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = leftHandOperand;
        operands[1] = rightHandOperand;
        TypeUtils.resolveNullOperands(operands);
        (success, result) = _executeArithmeticOperation(Operator.SafeMul, operands, true);
        emit SafeMul(msg.sender, operands[0], operands[1], success, result);
    }

    /// @inheritdoc INoxCompute
    function safeDiv(
        bytes32 numerator,
        bytes32 denominator
    ) external returns (bytes32 success, bytes32 result) {
        bytes32[] memory operands = new bytes32[](2);
        operands[0] = numerator;
        operands[1] = denominator;
        TypeUtils.resolveNullOperands(operands);
        (success, result) = _executeArithmeticOperation(Operator.SafeDiv, operands, true);
        emit SafeDiv(msg.sender, operands[0], operands[1], success, result);
    }

    /// @inheritdoc INoxCompute
    function select(
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) external returns (bytes32 result) {
        if (condition == bytes32(0)) {
            condition = TypeUtils.nullHandle(TEEType.Bool);
        }
        require(TypeUtils.typeOf(condition) == TEEType.Bool, UnsupportedType());
        bytes32[] memory valueOperands = new bytes32[](2);
        valueOperands[0] = ifTrue;
        valueOperands[1] = ifFalse;
        TypeUtils.resolveNullOperands(valueOperands);
        TEEType resultType = TypeUtils.typeOf(valueOperands[0]);
        require(resultType == TypeUtils.typeOf(valueOperands[1]), IncompatibleTypes());
        bytes32[] memory operands = new bytes32[](3);
        operands[0] = condition;
        operands[1] = valueOperands[0];
        operands[2] = valueOperands[1];
        validateAllowedForAll(msg.sender, operands);
        result = _generateHandle(Operator.Select, operands, resultType);
        _allowTransient(result, msg.sender);
        emit Select(msg.sender, condition, valueOperands[0], valueOperands[1], result);
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
        TypeUtils.resolveNullOperands(operands);
        (success, newBalanceFrom, newBalanceTo) = _executeCompositeOperation(
            Operator.Transfer,
            operands
        );
        emit Transfer(
            msg.sender,
            operands[0],
            operands[1],
            operands[2],
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
        TypeUtils.resolveNullOperands(operands);
        (success, newBalanceTo, newTotalSupply) = _executeCompositeOperation(
            Operator.Mint,
            operands
        );
        emit Mint(
            msg.sender,
            operands[0],
            operands[1],
            operands[2],
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
        TypeUtils.resolveNullOperands(operands);
        (success, newBalanceFrom, newTotalSupply) = _executeCompositeOperation(
            Operator.Burn,
            operands
        );
        emit Burn(
            msg.sender,
            operands[0],
            operands[1],
            operands[2],
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
        // Outputs differ by outputIndex and type, so they can safely share the same seed
        uint256 uniqueSeed = _generateHandleUniqueSeed(operands);
        result = _generateHandle(
            operator,
            operands,
            resultType,
            0,
            uniqueSeed,
            TypeUtils.ATTR_IS_UNIQUE_HANDLE
        );
        _allowTransient(result, msg.sender);
        if (isSafeOperation) {
            success = _generateHandle(
                operator,
                operands,
                TEEType.Bool,
                1,
                uniqueSeed,
                TypeUtils.ATTR_IS_UNIQUE_HANDLE
            );
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
     * @param operands Array of 2 operand handles (already resolved)
     * @return result The resulting Bool handle
     */
    function _executeComparisonOperation(
        Operator operator,
        bytes32[] memory operands
    ) private returns (bytes32 result) {
        TEEType operandType = TypeUtils.typeOf(operands[0]);
        TypeUtils.validateArithmeticType(operandType);
        require(TypeUtils.typeOf(operands[1]) == operandType, IncompatibleTypes());
        validateAllowedForAll(msg.sender, operands);
        result = _generateHandle(operator, operands, TEEType.Bool);
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
        // Outputs differ by outputIndex and type, so they can safely share the same seed
        uint256 uniqueSeed = _generateHandleUniqueSeed(operands);
        success = _generateHandle(
            operator,
            operands,
            TEEType.Bool,
            0,
            uniqueSeed,
            TypeUtils.ATTR_IS_UNIQUE_HANDLE
        );
        result1 = _generateHandle(
            operator,
            operands,
            resultType,
            1,
            uniqueSeed,
            TypeUtils.ATTR_IS_UNIQUE_HANDLE
        );
        result2 = _generateHandle(
            operator,
            operands,
            resultType,
            2,
            uniqueSeed,
            TypeUtils.ATTR_IS_UNIQUE_HANDLE
        );
        _allowTransient(success, msg.sender);
        _allowTransient(result1, msg.sender);
        _allowTransient(result2, msg.sender);
    }

    /**
     * @dev Alias for _generateHandle producing a public handle (outputIndex=0, uniqueSeed=0, attrs=0x00).
     */
    function _generatePublicHandle(
        Operator operator,
        bytes32[] memory operands,
        TEEType handleType
    ) private view returns (bytes32 result) {
        result = _generateHandle(operator, operands, handleType, 0, 0, bytes1(0x00));
    }

    /**
     * @dev Alias for single-output confidential operations (outputIndex=0, attrs=ATTR_IS_UNIQUE_HANDLE).
     * Computes the uniqueness seed internally.
     * Must NOT be called multiple times for multi-output operations (the seed counter would diverge).
     */
    function _generateHandle(
        Operator operator,
        bytes32[] memory operands,
        TEEType handleType
    ) private returns (bytes32 result) {
        uint256 uniqueSeed = _generateHandleUniqueSeed(operands);
        result = _generateHandle(
            operator,
            operands,
            handleType,
            0,
            uniqueSeed,
            TypeUtils.ATTR_IS_UNIQUE_HANDLE
        );
    }

    /**
     * Generates a complete handle from an operator and its operands.
     *
     * Pre-handle format:
     *   keccak256(abi.encode(
     *       operator,        // Operator identifier (e.g., Add, Sub, WrapAsPublicHandle)
     *       operands,        // Array of operand handles (or plaintext value)
     *       address(this),   // NoxCompute contract address
     *       uniqueSeed,        // Uniqueness seed (0 or counter value)
     *       outputIndex      // For operations that return multiple outputs
     *   ))
     *
     * Handle format (32 bytes):
     *   [0]    : Handle version
     *   [1-4]  : Chain ID (4 bytes, uint32)
     *   [5]    : TEE type
     *   [6]    : Attributes (bit 0 = isUniqueHandle)
     *   [7-31] : Truncated pre-handle hash (25 bytes)
     *
     * @param operator The operator to apply
     * @param operands Array of operand handles
     * @param handleType The TEE type to encode in the handle
     * @param outputIndex Index for operations returning multiple outputs
     * @param uniqueSeed Uniqueness seed (0 for wrapAsPublicHandle and unique operands)
     * @param attrs Attributes byte (0x00 for public handle, 0x01 for confidential)
     * @return result The complete handle with metadata appended
     */
    function _generateHandle(
        Operator operator,
        bytes32[] memory operands,
        TEEType handleType,
        uint8 outputIndex,
        uint256 uniqueSeed,
        bytes1 attrs
    ) private view returns (bytes32 result) {
        result = keccak256(abi.encode(operator, operands, address(this), uniqueSeed, outputIndex));
        // Shift hash to bytes 7-31 (truncate to 25 bytes), leaving bytes 0-6 free for metadata.
        result = result >> (7 * 8);
        result = result | bytes32(bytes1(uint8(HANDLE_VERSION)));
        result = result | (bytes32(bytes4(uint32(block.chainid))) >> (1 * 8));
        result = result | (bytes32(bytes1(uint8(handleType))) >> (5 * 8));
        result = result | (bytes32(attrs) >> (6 * 8));
    }

    /**
     * Determines the uniqueness seed for a confidential operation.
     * If at least one operand has isUniqueHandle=1, returns 0 (no storage access needed).
     * If all operands are public handles, increments a storage counter to guarantee uniqueness.
     * @param operands Array of operand handles
     * @return The uniqueness seed
     */
    function _generateHandleUniqueSeed(bytes32[] memory operands) private returns (uint256) {
        for (uint256 i = 0; i < operands.length; i++) {
            if (!TypeUtils.isPublicHandle(operands[i])) {
                return 0;
            }
        }
        // All operands are public handles: need storage counter for uniqueness
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return ++$.uniqueSeedCounter;
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
