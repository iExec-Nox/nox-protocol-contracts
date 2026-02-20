// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IErrors} from "./IErrors.sol";
import {IACL} from "./IACL.sol";
import {TEEType} from "../shared/TypeUtils.sol";

/**
 * @title INoxCompute
 * @notice Interface for the Nox compute contract powered by TEE.
 */
interface INoxCompute is IErrors {
    /// Error thrown when sender doesn't have access to the handle
    error UnauthorizedSender(address sender);
    /// Error thrown when an account is not allowed to use a handle
    error NotAllowed(bytes32 handle, address account);
    error InvalidProof(bytes proof, string reason);
    error IncompatibleTypes();

    /// Emitted when admin role is granted
    event Allowed(address indexed sender, address indexed account, bytes32 indexed handle);
    /// Emitted when viewer role is granted
    event ViewerAdded(address indexed sender, address indexed viewer, bytes32 indexed handle);
    /// Emitted when a handle is marked as publicly decryptable
    event MarkedAsPubliclyDecryptable(address indexed sender, bytes32 indexed handle);
    event KmsPublicKeyUpdated(bytes newKmsPublicKey);
    event GatewayUpdated(address indexed newGateway);
    event ProofExpirationDurationUpdated(uint256 newDuration);

    event PlaintextToEncrypted(
        address indexed caller,
        bytes32 plaintext,
        TEEType toType,
        bytes32 result
    );
    event Add(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Sub(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Div(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Mul(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Eq(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Ne(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Lt(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Le(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Gt(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event Ge(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 result
    );
    event SafeAdd(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 success,
        bytes32 result
    );
    event SafeSub(
        address indexed caller,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand,
        bytes32 success,
        bytes32 result
    );
    event Select(
        address indexed caller,
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse,
        bytes32 result
    );
    event Transfer(
        address indexed caller,
        bytes32 balanceFrom,
        bytes32 balanceTo,
        bytes32 amount,
        bytes32 success,
        bytes32 newBalanceFrom,
        bytes32 newBalanceTo
    );
    event Mint(
        address indexed caller,
        bytes32 balanceTo,
        bytes32 amount,
        bytes32 totalSupply,
        bytes32 success,
        bytes32 newBalanceTo,
        bytes32 newTotalSupply
    );
    event Burn(
        address indexed caller,
        bytes32 balanceFrom,
        bytes32 amount,
        bytes32 totalSupply,
        bytes32 success,
        bytes32 newBalanceFrom,
        bytes32 newTotalSupply
    );

    enum Operator {
        PlaintextToEncrypted,
        Add,
        Sub,
        Mul,
        Div,
        SafeAdd,
        SafeSub,
        Select,
        Eq,
        Ne,
        Lt,
        Le,
        Gt,
        Ge,
        Transfer,
        Mint,
        Burn
    }

    // ------------- ACL management -------------

    /**
     * Grant admin role to another address for a specific handle
     * @dev Caller must have access (transient OR persistent) to the handle
     * @param handle The handle identifier
     * @param account The address to grant admin role
     */
    function allow(bytes32 handle, address account) external;

    /**
     * Allows the use of `handle` by address `account` for this transaction.
     * @param handle Handle.
     * @param account Address of the account.
     */
    function allowTransient(bytes32 handle, address account) external;

    /**
     * Removes all transient authorizations. This is useful for integration with Account Abstraction
     * when bundling several UserOps calling the NoxCompute.
     * @dev Can be called by anyone (typically by AA bundlers between UserOps).
     */
    function cleanTransientStorage() external;

    /**
     * Returns whether the account is allowed to use the `handle`, either due to
     * allowTransient() or allow().
     * @param handle Handle.
     * @param account Address of the account.
     * @return Whether the account can access the handle (persistent or transient).
     */
    function isAllowed(bytes32 handle, address account) external view returns (bool);

    /**
     * Checks whether the account is allowed to use all provided handles.
     * Reverts with NotAllowed if any handle is not allowed.
     * @param account Address of the account.
     * @param handles Array of handles to check.
     */
    function validateAllowedForAll(address account, bytes32[] calldata handles) external view;

    /**
     * Add a viewer for a specific handle
     * @dev Only an admin can add a viewer. The viewer address cannot be address(0).
     * @param handle The handle identifier
     * @param viewer The address to grant viewer role
     */
    function addViewer(bytes32 handle, address viewer) external;

    /**
     * Returns whether the account can view the handle.
     * @dev Returns true if any of the following conditions are met:
     *      - The handle is publicly decryptable
     *      - The account was added as a viewer via `addViewer`
     *      - The account has persistent access (is allowed) on the handle
     * @param handle Handle.
     * @param viewer Address of the viewer.
     * @return Whether the account can view the handle.
     */
    function isViewer(bytes32 handle, address viewer) external view returns (bool);

    /**
     * Mark a handle as publicly decryptable.
     * @dev The caller must be allowed to use the handle.
     *      If not, the function reverts.
     * @param handle Handle to mark as publicly decryptable.
     */
    function allowPublicDecryption(bytes32 handle) external;

    /**
     * Checks whether a handle is publicly decryptable.
     * @param handle Handle.
     * @return Whether the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(bytes32 handle) external view returns (bool);

    // ------------- Admin functions -------------

    // TODO move admin functions to the bottom.
    /**
     * @notice Sets the KMS public key used for ECIES encryption
     * @param newKmsPublicKey The compressed SEC1 secp256k1 public key (33 bytes)
     */
    function setKmsPublicKey(bytes calldata newKmsPublicKey) external;

    function setGateway(address gatewayAddress) external;

    /**
     * @notice Sets the proof expiration duration
     * @param newDuration The new expiration duration in seconds
     */
    function setProofExpirationDuration(uint256 newDuration) external;

    // ------------- Compute functions -------------

    /**
     * @notice Converts a plaintext value into an encrypted value
     * @param value The plaintext value to encrypt
     * @param teeType The type of the encrypted value
     * @return The encrypted value
     */
    function plaintextToEncrypted(bytes32 value, TEEType teeType) external returns (bytes32);

    /**
     * @notice Computes TEE Add operation
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Result handle
     */
    function add(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Performs a subtraction between two encrypted values without safety checks.
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Result handle
     */
    function sub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Performs a division between two encrypted values
     * @param numerator Value to be divided
     * @param denominator Value to divide by
     * @return result Result handle
     */
    function div(bytes32 numerator, bytes32 denominator) external returns (bytes32 result);

    /**
     * @notice Performs a multiplication between two encrypted values
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Result handle
     */
    function mul(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Checks equality between two encrypted values
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Bool handle indicating equality
     */
    function eq(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Checks inequality between two encrypted values
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Bool handle indicating inequality
     */
    function ne(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Checks if left operand is less than right operand
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Bool handle indicating less than
     */
    function lt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Checks if left operand is less than or equal to right operand
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Bool handle indicating less than or equal
     */
    function le(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Checks if left operand is greater than right operand
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Bool handle indicating greater than
     */
    function gt(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    /**
     * @notice Checks if left operand is greater than or equal to right operand
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return result Bool handle indicating greater than or equal
     */
    function ge(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 result);

    // TODO for all safe operations, determine which cyphertexte linked to the new handle to return
    // as result in case of failure.
    /**
     * @notice Performs an addition between two encrypted values with safety checks.
     * The operation fails in the case of overflows.
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return success Whether the operation was successful
     * @return result Result handle
     */
    function safeAdd(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result);

    /**
     * @notice Performs a subtraction between two encrypted values with safety checks.
     * The operation fails in the case of underflow.
     * @param leftHandOperand Left-hand side operand handle
     * @param rightHandOperand Right-hand side operand handle
     * @return success Whether the operation was successful
     * @return result Result handle
     */
    function safeSub(
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) external returns (bytes32 success, bytes32 result);

    /**
     * @notice Selects between two encrypted values based on a condition
     * @param condition Condition handle
     * @param ifTrue Value handle if condition is true
     * @param ifFalse Value handle if condition is false
     * @return result Selected value handle
     */
    function select(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external returns (bytes32);

    /**
     * @notice Computes a confidential transfer between two balances.
     * @param balanceFrom Sender's current balance handle
     * @param balanceTo Recipient's current balance handle
     * @param amount Amount handle to transfer
     * @return success Bool handle indicating if the transfer succeeded
     * @return newBalanceFrom Sender's new balance handle
     * @return newBalanceTo Recipient's new balance handle
     */
    function transfer(
        bytes32 balanceFrom,
        bytes32 balanceTo,
        bytes32 amount
    ) external returns (bytes32 success, bytes32 newBalanceFrom, bytes32 newBalanceTo);

    /**
     * @notice Computes a confidential mint operation.
     * @param balanceTo Recipient's current balance handle
     * @param amount Amount handle to mint
     * @param totalSupply Current total supply handle
     * @return success Bool handle indicating if the mint succeeded
     * @return newBalanceTo Recipient's new balance handle
     * @return newTotalSupply New total supply handle
     */
    function mint(
        bytes32 balanceTo,
        bytes32 amount,
        bytes32 totalSupply
    ) external returns (bytes32 success, bytes32 newBalanceTo, bytes32 newTotalSupply);

    /**
     * @notice Computes a confidential burn operation.
     * @param balanceFrom Sender's current balance handle
     * @param amount Amount handle to burn
     * @param totalSupply Current total supply handle
     * @return success Bool handle indicating if the burn succeeded
     * @return newBalanceFrom Sender's new balance handle
     * @return newTotalSupply New total supply handle
     */
    function burn(
        bytes32 balanceFrom,
        bytes32 amount,
        bytes32 totalSupply
    ) external returns (bytes32 success, bytes32 newBalanceFrom, bytes32 newTotalSupply);

    function validateProof(
        bytes32 handle,
        address owner,
        bytes calldata proof,
        TEEType teeType
    ) external;

    function domainSeparator() external view returns (bytes32);
    function gateway() external view returns (address);
    function proofExpirationDuration() external view returns (uint256);
    function kmsPublicKey() external view returns (bytes memory);
}
