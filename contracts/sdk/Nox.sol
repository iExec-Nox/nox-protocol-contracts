// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {TEEType} from "../shared/TypeUtils.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";
import "encrypted-types/EncryptedTypes.sol";

/**
 * @title Nox
 * @notice Library providing convenient functions for TEE confidential computations.
 */
library Nox {
    // ============ Errors ============

    error UninitializedHandle();

    // ============ Address resolution ============

    /**
     * @dev Returns the NoxCompute contract address for the current chain.
     *      Supports Arbitrum Mainnet (42161), Arbitrum Sepolia (421614), and local dev chains (31337),
     *      including local forks of each network.
     */
    function noxComputeContract() internal view returns (address) {
        // Arbitrum mainnet or its fork
        if (block.chainid == 42161) {
            // TODO: Update after mainnet deployment.
            return address(0);
        }
        // Arbitrum Sepolia or its fork
        if (block.chainid == 421614) {
            return 0xE4622fbFCd0bDd482775bBf5b3e72382C0D99208;
        }
        // Local development chain
        if (block.chainid == 31337) {
            return 0x9bdef3F9fEc61eE7cDfE84BDE8398595c6E0b22d;
        }
        revert("Nox: Unsupported chain");
    }

    function _noxComputeContract() private view returns (INoxCompute) {
        return INoxCompute(noxComputeContract());
    }

    // =========== Handle initialization checks ============

    /**
     * @dev Checks if an encrypted boolean handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted boolean handle
     */
    function isInitialized(ebool handle) internal pure returns (bool) {
        return ebool.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted address handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted address handle
     */
    function isInitialized(eaddress handle) internal pure returns (bool) {
        return eaddress.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted uint16 handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted uint16 handle
     */
    function isInitialized(euint16 handle) internal pure returns (bool) {
        return euint16.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted uint256 handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted uint256 handle
     */
    function isInitialized(euint256 handle) internal pure returns (bool) {
        return euint256.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted int16 handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted int16 handle
     */
    function isInitialized(eint16 handle) internal pure returns (bool) {
        return eint16.unwrap(handle) != 0;
    }

    /**
     * @dev Checks if an encrypted int256 handle is initialized.
     * This is a basic check and does not guarantee that the handle
     * is valid or recognized by the ACL.
     * @param handle encrypted int256 handle
     */
    function isInitialized(eint256 handle) internal pure returns (bool) {
        return eint256.unwrap(handle) != 0;
    }

    // ============ Trivial Encryption Functions ============

    /**
     * @dev Converts a plaintext boolean to an encrypted boolean.
     */
    function toEbool(bool value) internal returns (ebool) {
        return
            ebool.wrap(
                _noxComputeContract().plaintextToEncrypted(
                    bytes32(uint256(value ? 1 : 0)),
                    TEEType.Bool
                )
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint16 integer.
     */
    function toEuint16(uint16 value) internal returns (euint16) {
        return
            euint16.wrap(
                _noxComputeContract().plaintextToEncrypted(bytes32(uint256(value)), TEEType.Uint16)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function toEuint256(uint256 value) internal returns (euint256) {
        return
            euint256.wrap(
                _noxComputeContract().plaintextToEncrypted(bytes32(value), TEEType.Uint256)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint16 integer.
     */
    function toEint16(int16 value) internal returns (eint16) {
        return
            eint16.wrap(
                _noxComputeContract().plaintextToEncrypted(
                    bytes32(uint256(uint16(value))),
                    TEEType.Int16
                )
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        return
            eint256.wrap(
                _noxComputeContract().plaintextToEncrypted(bytes32(uint256(value)), TEEType.Int256)
            );
    }

    // ============ Handle validation ============

    function fromExternal(
        externalEbool externalHandle,
        bytes calldata handleProof
    ) internal returns (ebool) {
        bytes32 handle = externalEbool.unwrap(externalHandle);
        _noxComputeContract().validateInputProof(handle, msg.sender, handleProof, TEEType.Bool);
        return ebool.wrap(handle);
    }

    function fromExternal(
        externalEaddress externalHandle,
        bytes calldata handleProof
    ) internal returns (eaddress) {
        bytes32 handle = externalEaddress.unwrap(externalHandle);
        _noxComputeContract().validateInputProof(handle, msg.sender, handleProof, TEEType.Address);
        return eaddress.wrap(handle);
    }

    function fromExternal(
        externalEuint16 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint16) {
        bytes32 handle = externalEuint16.unwrap(externalHandle);
        _noxComputeContract().validateInputProof(handle, msg.sender, handleProof, TEEType.Uint16);
        return euint16.wrap(handle);
    }

    function fromExternal(
        externalEuint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint256) {
        bytes32 handle = externalEuint256.unwrap(externalHandle);
        _noxComputeContract().validateInputProof(handle, msg.sender, handleProof, TEEType.Uint256);
        return euint256.wrap(handle);
    }

    function fromExternal(
        externalEint16 externalHandle,
        bytes calldata handleProof
    ) internal returns (eint16) {
        bytes32 handle = externalEint16.unwrap(externalHandle);
        _noxComputeContract().validateInputProof(handle, msg.sender, handleProof, TEEType.Int16);
        return eint16.wrap(handle);
    }

    function fromExternal(
        externalEint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (eint256) {
        bytes32 handle = externalEint256.unwrap(externalHandle);
        _noxComputeContract().validateInputProof(handle, msg.sender, handleProof, TEEType.Int256);
        return eint256.wrap(handle);
    }

    // ============ Arithmetic primitives ============

    function add(euint16 a, euint16 b) internal returns (euint16) {
        return euint16.wrap(_add(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function add(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_add(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function add(eint16 a, eint16 b) internal returns (eint16) {
        return eint16.wrap(_add(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function add(eint256 a, eint256 b) internal returns (eint256) {
        return eint256.wrap(_add(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function sub(euint16 a, euint16 b) internal returns (euint16) {
        return euint16.wrap(_sub(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function sub(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_sub(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function sub(eint16 a, eint16 b) internal returns (eint16) {
        return eint16.wrap(_sub(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function sub(eint256 a, eint256 b) internal returns (eint256) {
        return eint256.wrap(_sub(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function mul(euint16 a, euint16 b) internal returns (euint16) {
        return euint16.wrap(_mul(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function mul(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_mul(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function mul(eint16 a, eint16 b) internal returns (eint16) {
        return eint16.wrap(_mul(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function mul(eint256 a, eint256 b) internal returns (eint256) {
        return eint256.wrap(_mul(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function div(euint16 a, euint16 b) internal returns (euint16) {
        return euint16.wrap(_div(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function div(euint256 a, euint256 b) internal returns (euint256) {
        return euint256.wrap(_div(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function div(eint16 a, eint16 b) internal returns (eint16) {
        return eint16.wrap(_div(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function div(eint256 a, eint256 b) internal returns (eint256) {
        return eint256.wrap(_div(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function safeAdd(euint16 a, euint16 b) internal returns (ebool, euint16) {
        (bytes32 success, bytes32 result) = _safeAdd(euint16.unwrap(a), euint16.unwrap(b));
        return (ebool.wrap(success), euint16.wrap(result));
    }

    function safeAdd(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = _safeAdd(euint256.unwrap(a), euint256.unwrap(b));
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeAdd(eint16 a, eint16 b) internal returns (ebool, eint16) {
        (bytes32 success, bytes32 result) = _safeAdd(eint16.unwrap(a), eint16.unwrap(b));
        return (ebool.wrap(success), eint16.wrap(result));
    }

    function safeAdd(eint256 a, eint256 b) internal returns (ebool, eint256) {
        (bytes32 success, bytes32 result) = _safeAdd(eint256.unwrap(a), eint256.unwrap(b));
        return (ebool.wrap(success), eint256.wrap(result));
    }

    function safeSub(euint16 a, euint16 b) internal returns (ebool, euint16) {
        (bytes32 success, bytes32 result) = _safeSub(euint16.unwrap(a), euint16.unwrap(b));
        return (ebool.wrap(success), euint16.wrap(result));
    }

    function safeSub(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = _safeSub(euint256.unwrap(a), euint256.unwrap(b));
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeSub(eint16 a, eint16 b) internal returns (ebool, eint16) {
        (bytes32 success, bytes32 result) = _safeSub(eint16.unwrap(a), eint16.unwrap(b));
        return (ebool.wrap(success), eint16.wrap(result));
    }

    function safeSub(eint256 a, eint256 b) internal returns (ebool, eint256) {
        (bytes32 success, bytes32 result) = _safeSub(eint256.unwrap(a), eint256.unwrap(b));
        return (ebool.wrap(success), eint256.wrap(result));
    }

    function safeMul(euint16 a, euint16 b) internal returns (ebool, euint16) {
        (bytes32 success, bytes32 result) = _safeMul(euint16.unwrap(a), euint16.unwrap(b));
        return (ebool.wrap(success), euint16.wrap(result));
    }

    function safeMul(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = _safeMul(euint256.unwrap(a), euint256.unwrap(b));
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeMul(eint16 a, eint16 b) internal returns (ebool, eint16) {
        (bytes32 success, bytes32 result) = _safeMul(eint16.unwrap(a), eint16.unwrap(b));
        return (ebool.wrap(success), eint16.wrap(result));
    }

    function safeMul(eint256 a, eint256 b) internal returns (ebool, eint256) {
        (bytes32 success, bytes32 result) = _safeMul(eint256.unwrap(a), eint256.unwrap(b));
        return (ebool.wrap(success), eint256.wrap(result));
    }

    function safeDiv(euint16 a, euint16 b) internal returns (ebool, euint16) {
        (bytes32 success, bytes32 result) = _safeDiv(euint16.unwrap(a), euint16.unwrap(b));
        return (ebool.wrap(success), euint16.wrap(result));
    }

    function safeDiv(euint256 a, euint256 b) internal returns (ebool, euint256) {
        (bytes32 success, bytes32 result) = _safeDiv(euint256.unwrap(a), euint256.unwrap(b));
        return (ebool.wrap(success), euint256.wrap(result));
    }

    function safeDiv(eint16 a, eint16 b) internal returns (ebool, eint16) {
        (bytes32 success, bytes32 result) = _safeDiv(eint16.unwrap(a), eint16.unwrap(b));
        return (ebool.wrap(success), eint16.wrap(result));
    }

    function safeDiv(eint256 a, eint256 b) internal returns (ebool, eint256) {
        (bytes32 success, bytes32 result) = _safeDiv(eint256.unwrap(a), eint256.unwrap(b));
        return (ebool.wrap(success), eint256.wrap(result));
    }

    function select(ebool condition, euint16 ifTrue, euint16 ifFalse) internal returns (euint16) {
        return
            euint16.wrap(
                _select(ebool.unwrap(condition), euint16.unwrap(ifTrue), euint16.unwrap(ifFalse))
            );
    }

    function select(
        ebool condition,
        euint256 ifTrue,
        euint256 ifFalse
    ) internal returns (euint256) {
        return
            euint256.wrap(
                _select(ebool.unwrap(condition), euint256.unwrap(ifTrue), euint256.unwrap(ifFalse))
            );
    }

    function select(ebool condition, eint16 ifTrue, eint16 ifFalse) internal returns (eint16) {
        return
            eint16.wrap(
                _select(ebool.unwrap(condition), eint16.unwrap(ifTrue), eint16.unwrap(ifFalse))
            );
    }

    function select(ebool condition, eint256 ifTrue, eint256 ifFalse) internal returns (eint256) {
        return
            eint256.wrap(
                _select(ebool.unwrap(condition), eint256.unwrap(ifTrue), eint256.unwrap(ifFalse))
            );
    }

    function eq(euint16 a, euint16 b) internal returns (ebool) {
        return ebool.wrap(_eq(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function eq(euint256 a, euint256 b) internal returns (ebool) {
        return ebool.wrap(_eq(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function eq(eint16 a, eint16 b) internal returns (ebool) {
        return ebool.wrap(_eq(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function eq(eint256 a, eint256 b) internal returns (ebool) {
        return ebool.wrap(_eq(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function ne(euint16 a, euint16 b) internal returns (ebool) {
        return ebool.wrap(_ne(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function ne(euint256 a, euint256 b) internal returns (ebool) {
        return ebool.wrap(_ne(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function ne(eint16 a, eint16 b) internal returns (ebool) {
        return ebool.wrap(_ne(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function ne(eint256 a, eint256 b) internal returns (ebool) {
        return ebool.wrap(_ne(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function lt(euint16 a, euint16 b) internal returns (ebool) {
        return ebool.wrap(_lt(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function lt(euint256 a, euint256 b) internal returns (ebool) {
        return ebool.wrap(_lt(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function lt(eint16 a, eint16 b) internal returns (ebool) {
        return ebool.wrap(_lt(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function lt(eint256 a, eint256 b) internal returns (ebool) {
        return ebool.wrap(_lt(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function le(euint16 a, euint16 b) internal returns (ebool) {
        return ebool.wrap(_le(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function le(euint256 a, euint256 b) internal returns (ebool) {
        return ebool.wrap(_le(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function le(eint16 a, eint16 b) internal returns (ebool) {
        return ebool.wrap(_le(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function le(eint256 a, eint256 b) internal returns (ebool) {
        return ebool.wrap(_le(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function gt(euint16 a, euint16 b) internal returns (ebool) {
        return ebool.wrap(_gt(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function gt(euint256 a, euint256 b) internal returns (ebool) {
        return ebool.wrap(_gt(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function gt(eint16 a, eint16 b) internal returns (ebool) {
        return ebool.wrap(_gt(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function gt(eint256 a, eint256 b) internal returns (ebool) {
        return ebool.wrap(_gt(eint256.unwrap(a), eint256.unwrap(b)));
    }

    function ge(euint16 a, euint16 b) internal returns (ebool) {
        return ebool.wrap(_ge(euint16.unwrap(a), euint16.unwrap(b)));
    }

    function ge(euint256 a, euint256 b) internal returns (ebool) {
        return ebool.wrap(_ge(euint256.unwrap(a), euint256.unwrap(b)));
    }

    function ge(eint16 a, eint16 b) internal returns (ebool) {
        return ebool.wrap(_ge(eint16.unwrap(a), eint16.unwrap(b)));
    }

    function ge(eint256 a, eint256 b) internal returns (ebool) {
        return ebool.wrap(_ge(eint256.unwrap(a), eint256.unwrap(b)));
    }

    // ============ ADVANCED FUNCTIONS ============

    /**
     * @dev Atomically transfers `amount` from `balanceFrom` to `balanceTo`.
     * Returns the new balances and whether the transfer was successful.
     * The transfer will fail if `balanceFrom < amount`.
     */
    function transfer(
        euint256 balanceFrom,
        euint256 balanceTo,
        euint256 amount
    ) internal returns (ebool success, euint256 newBalanceFrom, euint256 newBalanceTo) {
        (bytes32 _success, bytes32 _newBalanceFrom, bytes32 _newBalanceTo) = _transfer(
            euint256.unwrap(balanceFrom),
            euint256.unwrap(balanceTo),
            euint256.unwrap(amount)
        );
        success = ebool.wrap(_success);
        newBalanceFrom = euint256.wrap(_newBalanceFrom);
        newBalanceTo = euint256.wrap(_newBalanceTo);
    }

    /**
     * @dev Atomically mints `amount` to `balanceTo` and increases `totalSupply` by `amount`.
     * Returns the new balance, new total supply, and whether the mint was successful.
     * The mint will fail if `totalSupply + amount` overflows.
     */
    function mint(
        euint256 balanceTo,
        euint256 amount,
        euint256 totalSupply
    ) internal returns (ebool success, euint256 newBalanceTo, euint256 newTotalSupply) {
        (bytes32 _success, bytes32 _newBalanceTo, bytes32 _newTotalSupply) = _mint(
            euint256.unwrap(balanceTo),
            euint256.unwrap(amount),
            euint256.unwrap(totalSupply)
        );
        success = ebool.wrap(_success);
        newBalanceTo = euint256.wrap(_newBalanceTo);
        newTotalSupply = euint256.wrap(_newTotalSupply);
    }

    /**
     * @dev Atomically burns `amount` from `balanceFrom` and decreases `totalSupply` by `amount`.
     * Returns the new balance, new total supply, and whether the burn was successful.
     * The burn will fail if `balanceFrom < amount`.
     */
    function burn(
        euint256 balanceFrom,
        euint256 amount,
        euint256 totalSupply
    ) internal returns (ebool success, euint256 newBalanceFrom, euint256 newTotalSupply) {
        (bytes32 _success, bytes32 _newBalanceFrom, bytes32 _newTotalSupply) = _burn(
            euint256.unwrap(balanceFrom),
            euint256.unwrap(amount),
            euint256.unwrap(totalSupply)
        );
        success = ebool.wrap(_success);
        newBalanceFrom = euint256.wrap(_newBalanceFrom);
        newTotalSupply = euint256.wrap(_newTotalSupply);
    }

    // ============ PERMISSION MANAGEMENT ============

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(ebool value, address account) internal {
        _noxComputeContract().allow(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal {
        _noxComputeContract().allow(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint16 value, address account) internal {
        _noxComputeContract().allow(euint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal {
        _noxComputeContract().allow(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint16 value, address account) internal {
        _noxComputeContract().allow(eint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal {
        _noxComputeContract().allow(eint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal {
        _noxComputeContract().allow(ebool.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal {
        _noxComputeContract().allow(eaddress.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint16 value) internal {
        _noxComputeContract().allow(euint16.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal {
        _noxComputeContract().allow(euint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint16 value) internal {
        _noxComputeContract().allow(eint16.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal {
        _noxComputeContract().allow(eint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal {
        _noxComputeContract().allowTransient(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal {
        _noxComputeContract().allowTransient(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint16 value, address account) internal {
        _noxComputeContract().allowTransient(euint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal {
        _noxComputeContract().allowTransient(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint16 value, address account) internal {
        _noxComputeContract().allowTransient(eint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal {
        _noxComputeContract().allowTransient(eint256.unwrap(value), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(ebool handle, address account) internal view returns (bool) {
        return _noxComputeContract().isAllowed(ebool.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eaddress handle, address account) internal view returns (bool) {
        return _noxComputeContract().isAllowed(eaddress.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint16 handle, address account) internal view returns (bool) {
        return _noxComputeContract().isAllowed(euint16.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint256 handle, address account) internal view returns (bool) {
        return _noxComputeContract().isAllowed(euint256.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eint16 handle, address account) internal view returns (bool) {
        return _noxComputeContract().isAllowed(eint16.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eint256 handle, address account) internal view returns (bool) {
        return _noxComputeContract().isAllowed(eint256.unwrap(handle), account);
    }

    // ============ VIEWER MANAGEMENT ============

    /**
     * @dev Adds a viewer for an ebool handle.
     */
    function addViewer(ebool value, address viewer) internal {
        _noxComputeContract().addViewer(ebool.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eaddress handle.
     */
    function addViewer(eaddress value, address viewer) internal {
        _noxComputeContract().addViewer(eaddress.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an euint16 handle.
     */
    function addViewer(euint16 value, address viewer) internal {
        _noxComputeContract().addViewer(euint16.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an euint256 handle.
     */
    function addViewer(euint256 value, address viewer) internal {
        _noxComputeContract().addViewer(euint256.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eint16 handle.
     */
    function addViewer(eint16 value, address viewer) internal {
        _noxComputeContract().addViewer(eint16.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eint256 handle.
     */
    function addViewer(eint256 value, address viewer) internal {
        _noxComputeContract().addViewer(eint256.unwrap(value), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(ebool handle, address viewer) internal view returns (bool) {
        return _noxComputeContract().isViewer(ebool.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eaddress handle, address viewer) internal view returns (bool) {
        return _noxComputeContract().isViewer(eaddress.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(euint16 handle, address viewer) internal view returns (bool) {
        return _noxComputeContract().isViewer(euint16.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(euint256 handle, address viewer) internal view returns (bool) {
        return _noxComputeContract().isViewer(euint256.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eint16 handle, address viewer) internal view returns (bool) {
        return _noxComputeContract().isViewer(eint16.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eint256 handle, address viewer) internal view returns (bool) {
        return _noxComputeContract().isViewer(eint256.unwrap(handle), viewer);
    }

    // ============ PUBLIC DECRYPTION ============

    /**
     * @dev Marks an ebool handle as publicly decryptable.
     */
    function allowPublicDecryption(ebool value) internal {
        _noxComputeContract().allowPublicDecryption(ebool.unwrap(value));
    }

    /**
     * @dev Marks an eaddress handle as publicly decryptable.
     */
    function allowPublicDecryption(eaddress value) internal {
        _noxComputeContract().allowPublicDecryption(eaddress.unwrap(value));
    }

    /**
     * @dev Marks an euint16 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint16 value) internal {
        _noxComputeContract().allowPublicDecryption(euint16.unwrap(value));
    }

    /**
     * @dev Marks an euint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint256 value) internal {
        _noxComputeContract().allowPublicDecryption(euint256.unwrap(value));
    }

    /**
     * @dev Marks an eint16 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint16 value) internal {
        _noxComputeContract().allowPublicDecryption(eint16.unwrap(value));
    }

    /**
     * @dev Marks an eint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint256 value) internal {
        _noxComputeContract().allowPublicDecryption(eint256.unwrap(value));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(ebool handle) internal view returns (bool) {
        return _noxComputeContract().isPubliclyDecryptable(ebool.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eaddress handle) internal view returns (bool) {
        return _noxComputeContract().isPubliclyDecryptable(eaddress.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(euint16 handle) internal view returns (bool) {
        return _noxComputeContract().isPubliclyDecryptable(euint16.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(euint256 handle) internal view returns (bool) {
        return _noxComputeContract().isPubliclyDecryptable(euint256.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eint16 handle) internal view returns (bool) {
        return _noxComputeContract().isPubliclyDecryptable(eint16.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eint256 handle) internal view returns (bool) {
        return _noxComputeContract().isPubliclyDecryptable(eint256.unwrap(handle));
    }

    // ============ Public decryption proof verification ============

    /**
     * @dev Verifies a decryption proof and returns the decrypted boolean value.
     */
    function publicDecrypt(ebool handle, bytes calldata decryptionProof) internal returns (bool) {
        bytes memory result = _noxComputeContract().validateDecryptionProof(
            ebool.unwrap(handle),
            decryptionProof
        );
        return abi.decode(result, (bool));
    }

    /**
     * @dev Verifies a decryption proof and returns the decrypted address value.
     */
    function publicDecrypt(
        eaddress handle,
        bytes calldata decryptionProof
    ) internal returns (address) {
        bytes memory result = _noxComputeContract().validateDecryptionProof(
            eaddress.unwrap(handle),
            decryptionProof
        );
        return abi.decode(result, (address));
    }

    /**
     * @dev Verifies a decryption proof and returns the decrypted uint16 value.
     */
    function publicDecrypt(
        euint16 handle,
        bytes calldata decryptionProof
    ) internal returns (uint16) {
        bytes memory result = _noxComputeContract().validateDecryptionProof(
            euint16.unwrap(handle),
            decryptionProof
        );
        return abi.decode(result, (uint16));
    }

    /**
     * @dev Verifies a decryption proof and returns the decrypted uint256 value.
     */
    function publicDecrypt(
        euint256 handle,
        bytes calldata decryptionProof
    ) internal returns (uint256) {
        bytes memory result = _noxComputeContract().validateDecryptionProof(
            euint256.unwrap(handle),
            decryptionProof
        );
        return abi.decode(result, (uint256));
    }

    /**
     * @dev Verifies a decryption proof and returns the decrypted int16 value.
     */
    function publicDecrypt(eint16 handle, bytes calldata decryptionProof) internal returns (int16) {
        bytes memory result = _noxComputeContract().validateDecryptionProof(
            eint16.unwrap(handle),
            decryptionProof
        );
        return abi.decode(result, (int16));
    }

    /**
     * @dev Verifies a decryption proof and returns the decrypted int256 value.
     */
    function publicDecrypt(
        eint256 handle,
        bytes calldata decryptionProof
    ) internal returns (int256) {
        bytes memory result = _noxComputeContract().validateDecryptionProof(
            eint256.unwrap(handle),
            decryptionProof
        );
        return abi.decode(result, (int256));
    }

    // ============ Private helpers ============

    function _assertInitialized(bytes32 handle) private pure {
        require(handle != bytes32(0), UninitializedHandle());
    }

    function _add(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().add(a, b);
    }

    function _sub(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().sub(a, b);
    }

    function _mul(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().mul(a, b);
    }

    function _div(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().div(a, b);
    }

    function _safeAdd(bytes32 a, bytes32 b) private returns (bytes32, bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().safeAdd(a, b);
    }

    function _safeSub(bytes32 a, bytes32 b) private returns (bytes32, bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().safeSub(a, b);
    }

    function _safeMul(bytes32 a, bytes32 b) private returns (bytes32, bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().safeMul(a, b);
    }

    function _safeDiv(bytes32 a, bytes32 b) private returns (bytes32, bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().safeDiv(a, b);
    }

    function _select(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) private returns (bytes32) {
        _assertInitialized(condition);
        _assertInitialized(ifTrue);
        _assertInitialized(ifFalse);
        return _noxComputeContract().select(condition, ifTrue, ifFalse);
    }

    function _eq(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().eq(a, b);
    }

    function _ne(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().ne(a, b);
    }

    function _lt(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().lt(a, b);
    }

    function _le(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().le(a, b);
    }

    function _gt(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().gt(a, b);
    }

    function _ge(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return _noxComputeContract().ge(a, b);
    }

    function _transfer(
        bytes32 balanceFrom,
        bytes32 balanceTo,
        bytes32 amount
    ) private returns (bytes32, bytes32, bytes32) {
        _assertInitialized(balanceFrom);
        _assertInitialized(balanceTo);
        _assertInitialized(amount);
        return _noxComputeContract().transfer(balanceFrom, balanceTo, amount);
    }

    function _mint(
        bytes32 balanceTo,
        bytes32 amount,
        bytes32 totalSupply
    ) private returns (bytes32, bytes32, bytes32) {
        _assertInitialized(balanceTo);
        _assertInitialized(amount);
        _assertInitialized(totalSupply);
        return _noxComputeContract().mint(balanceTo, amount, totalSupply);
    }

    function _burn(
        bytes32 balanceFrom,
        bytes32 amount,
        bytes32 totalSupply
    ) private returns (bytes32, bytes32, bytes32) {
        _assertInitialized(balanceFrom);
        _assertInitialized(amount);
        _assertInitialized(totalSupply);
        return _noxComputeContract().burn(balanceFrom, amount, totalSupply);
    }
}
