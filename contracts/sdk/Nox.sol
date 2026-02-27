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
    function getNoxCompute() public view returns (INoxCompute) {
        // Arbitrum mainnet or its fork
        if (block.chainid == 42161) {
            // TODO: Update after mainnet deployment.
            return INoxCompute(0x5633472D35E18464CA24Ab974954fB3b1B122eA6);
        }
        // Arbitrum Sepolia or its fork
        if (block.chainid == 421614) {
            return INoxCompute(0x5633472D35E18464CA24Ab974954fB3b1B122eA6);
        }
        // Local development chain
        if (block.chainid == 31337) {
            return INoxCompute(0x188D560Fd7F60f50e4c32a4484B1D0DC486714b3);
        }
        revert("Nox: Unsupported chain");
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
                getNoxCompute().plaintextToEncrypted(bytes32(uint256(value ? 1 : 0)), TEEType.Bool)
            );
    }

    /**
     * @dev Convert a plaintext address to an encrypted address.
     */
    function toEaddress(address value) internal returns (eaddress) {
        return
            eaddress.wrap(
                getNoxCompute().plaintextToEncrypted(
                    bytes32(uint256(uint160(value))),
                    TEEType.Address
                )
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint16 integer.
     */
    function toEuint16(uint16 value) internal returns (euint16) {
        return
            euint16.wrap(
                getNoxCompute().plaintextToEncrypted(bytes32(uint256(value)), TEEType.Uint16)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted euint256 integer.
     */
    function toEuint256(uint256 value) internal returns (euint256) {
        return euint256.wrap(getNoxCompute().plaintextToEncrypted(bytes32(value), TEEType.Uint256));
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint16 integer.
     */
    function toEint16(int16 value) internal returns (eint16) {
        return
            eint16.wrap(
                getNoxCompute().plaintextToEncrypted(bytes32(uint256(uint16(value))), TEEType.Int16)
            );
    }

    /**
     * @dev Convert a plaintext value to an encrypted eint256 integer.
     */
    function toEint256(int256 value) internal returns (eint256) {
        return
            eint256.wrap(
                getNoxCompute().plaintextToEncrypted(bytes32(uint256(value)), TEEType.Int256)
            );
    }

    // ============ Handle validation ============

    function fromExternal(
        externalEbool externalHandle,
        bytes calldata handleProof
    ) internal returns (ebool) {
        bytes32 handle = externalEbool.unwrap(externalHandle);
        getNoxCompute().validateProof(handle, msg.sender, handleProof, TEEType.Bool);
        return ebool.wrap(handle);
    }

    function fromExternal(
        externalEaddress externalHandle,
        bytes calldata handleProof
    ) internal returns (eaddress) {
        bytes32 handle = externalEaddress.unwrap(externalHandle);
        getNoxCompute().validateProof(handle, msg.sender, handleProof, TEEType.Address);
        return eaddress.wrap(handle);
    }

    function fromExternal(
        externalEuint16 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint16) {
        bytes32 handle = externalEuint16.unwrap(externalHandle);
        getNoxCompute().validateProof(handle, msg.sender, handleProof, TEEType.Uint16);
        return euint16.wrap(handle);
    }

    function fromExternal(
        externalEuint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (euint256) {
        bytes32 handle = externalEuint256.unwrap(externalHandle);
        getNoxCompute().validateProof(handle, msg.sender, handleProof, TEEType.Uint256);
        return euint256.wrap(handle);
    }

    function fromExternal(
        externalEint16 externalHandle,
        bytes calldata handleProof
    ) internal returns (eint16) {
        bytes32 handle = externalEint16.unwrap(externalHandle);
        getNoxCompute().validateProof(handle, msg.sender, handleProof, TEEType.Int16);
        return eint16.wrap(handle);
    }

    function fromExternal(
        externalEint256 externalHandle,
        bytes calldata handleProof
    ) internal returns (eint256) {
        bytes32 handle = externalEint256.unwrap(externalHandle);
        getNoxCompute().validateProof(handle, msg.sender, handleProof, TEEType.Int256);
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

    // TODO add safeMul and safeDiv.

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
        getNoxCompute().allow(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eaddress value, address account) internal {
        getNoxCompute().allow(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint16 value, address account) internal {
        getNoxCompute().allow(euint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(euint256 value, address account) internal {
        getNoxCompute().allow(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint16 value, address account) internal {
        getNoxCompute().allow(eint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for the address account.
     */
    function allow(eint256 value, address account) internal {
        getNoxCompute().allow(eint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(ebool value) internal {
        getNoxCompute().allow(ebool.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eaddress value) internal {
        getNoxCompute().allow(eaddress.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint16 value) internal {
        getNoxCompute().allow(euint16.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(euint256 value) internal {
        getNoxCompute().allow(euint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint16 value) internal {
        getNoxCompute().allow(eint16.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value for this address (address(this)).
     */
    function allowThis(eint256 value) internal {
        getNoxCompute().allow(eint256.unwrap(value), address(this));
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(ebool value, address account) internal {
        getNoxCompute().allowTransient(ebool.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eaddress value, address account) internal {
        getNoxCompute().allowTransient(eaddress.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint16 value, address account) internal {
        getNoxCompute().allowTransient(euint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(euint256 value, address account) internal {
        getNoxCompute().allowTransient(euint256.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint16 value, address account) internal {
        getNoxCompute().allowTransient(eint16.unwrap(value), account);
    }

    /**
     * @dev Allows the use of value by address account for this transaction.
     */
    function allowTransient(eint256 value, address account) internal {
        getNoxCompute().allowTransient(eint256.unwrap(value), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(ebool handle, address account) internal view returns (bool) {
        return getNoxCompute().isAllowed(ebool.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eaddress handle, address account) internal view returns (bool) {
        return getNoxCompute().isAllowed(eaddress.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint16 handle, address account) internal view returns (bool) {
        return getNoxCompute().isAllowed(euint16.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(euint256 handle, address account) internal view returns (bool) {
        return getNoxCompute().isAllowed(euint256.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eint16 handle, address account) internal view returns (bool) {
        return getNoxCompute().isAllowed(eint16.unwrap(handle), account);
    }

    /**
     * @dev Checks if the handle is allowed for the account.
     */
    function isAllowed(eint256 handle, address account) internal view returns (bool) {
        return getNoxCompute().isAllowed(eint256.unwrap(handle), account);
    }

    // ============ VIEWER MANAGEMENT ============

    /**
     * @dev Adds a viewer for an ebool handle.
     */
    function addViewer(ebool value, address viewer) internal {
        getNoxCompute().addViewer(ebool.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eaddress handle.
     */
    function addViewer(eaddress value, address viewer) internal {
        getNoxCompute().addViewer(eaddress.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an euint16 handle.
     */
    function addViewer(euint16 value, address viewer) internal {
        getNoxCompute().addViewer(euint16.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an euint256 handle.
     */
    function addViewer(euint256 value, address viewer) internal {
        getNoxCompute().addViewer(euint256.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eint16 handle.
     */
    function addViewer(eint16 value, address viewer) internal {
        getNoxCompute().addViewer(eint16.unwrap(value), viewer);
    }

    /**
     * @dev Adds a viewer for an eint256 handle.
     */
    function addViewer(eint256 value, address viewer) internal {
        getNoxCompute().addViewer(eint256.unwrap(value), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(ebool handle, address viewer) internal view returns (bool) {
        return getNoxCompute().isViewer(ebool.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eaddress handle, address viewer) internal view returns (bool) {
        return getNoxCompute().isViewer(eaddress.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(euint16 handle, address viewer) internal view returns (bool) {
        return getNoxCompute().isViewer(euint16.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(euint256 handle, address viewer) internal view returns (bool) {
        return getNoxCompute().isViewer(euint256.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eint16 handle, address viewer) internal view returns (bool) {
        return getNoxCompute().isViewer(eint16.unwrap(handle), viewer);
    }

    /**
     * @dev Checks if the viewer can view the handle.
     */
    function isViewer(eint256 handle, address viewer) internal view returns (bool) {
        return getNoxCompute().isViewer(eint256.unwrap(handle), viewer);
    }

    // ============ PUBLIC DECRYPTION ============

    /**
     * @dev Marks an ebool handle as publicly decryptable.
     */
    function allowPublicDecryption(ebool value) internal {
        getNoxCompute().allowPublicDecryption(ebool.unwrap(value));
    }

    /**
     * @dev Marks an eaddress handle as publicly decryptable.
     */
    function allowPublicDecryption(eaddress value) internal {
        getNoxCompute().allowPublicDecryption(eaddress.unwrap(value));
    }

    /**
     * @dev Marks an euint16 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint16 value) internal {
        getNoxCompute().allowPublicDecryption(euint16.unwrap(value));
    }

    /**
     * @dev Marks an euint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(euint256 value) internal {
        getNoxCompute().allowPublicDecryption(euint256.unwrap(value));
    }

    /**
     * @dev Marks an eint16 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint16 value) internal {
        getNoxCompute().allowPublicDecryption(eint16.unwrap(value));
    }

    /**
     * @dev Marks an eint256 handle as publicly decryptable.
     */
    function allowPublicDecryption(eint256 value) internal {
        getNoxCompute().allowPublicDecryption(eint256.unwrap(value));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(ebool handle) internal view returns (bool) {
        return getNoxCompute().isPubliclyDecryptable(ebool.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eaddress handle) internal view returns (bool) {
        return getNoxCompute().isPubliclyDecryptable(eaddress.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(euint16 handle) internal view returns (bool) {
        return getNoxCompute().isPubliclyDecryptable(euint16.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(euint256 handle) internal view returns (bool) {
        return getNoxCompute().isPubliclyDecryptable(euint256.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eint16 handle) internal view returns (bool) {
        return getNoxCompute().isPubliclyDecryptable(eint16.unwrap(handle));
    }

    /**
     * @dev Checks if the handle is publicly decryptable.
     */
    function isPubliclyDecryptable(eint256 handle) internal view returns (bool) {
        return getNoxCompute().isPubliclyDecryptable(eint256.unwrap(handle));
    }

    // ============ Private helpers ============

    function _assertInitialized(bytes32 handle) private pure {
        require(handle != bytes32(0), UninitializedHandle());
    }

    function _add(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().add(a, b);
    }

    function _sub(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().sub(a, b);
    }

    function _mul(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().mul(a, b);
    }

    function _div(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().div(a, b);
    }

    function _safeAdd(bytes32 a, bytes32 b) private returns (bytes32, bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().safeAdd(a, b);
    }

    function _safeSub(bytes32 a, bytes32 b) private returns (bytes32, bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().safeSub(a, b);
    }

    function _select(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) private returns (bytes32) {
        _assertInitialized(condition);
        _assertInitialized(ifTrue);
        _assertInitialized(ifFalse);
        return getNoxCompute().select(condition, ifTrue, ifFalse);
    }

    function _eq(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().eq(a, b);
    }

    function _ne(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().ne(a, b);
    }

    function _lt(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().lt(a, b);
    }

    function _le(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().le(a, b);
    }

    function _gt(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().gt(a, b);
    }

    function _ge(bytes32 a, bytes32 b) private returns (bytes32) {
        _assertInitialized(a);
        _assertInitialized(b);
        return getNoxCompute().ge(a, b);
    }

    function _transfer(
        bytes32 balanceFrom,
        bytes32 balanceTo,
        bytes32 amount
    ) private returns (bytes32, bytes32, bytes32) {
        _assertInitialized(balanceFrom);
        _assertInitialized(balanceTo);
        _assertInitialized(amount);
        return getNoxCompute().transfer(balanceFrom, balanceTo, amount);
    }

    function _mint(
        bytes32 balanceTo,
        bytes32 amount,
        bytes32 totalSupply
    ) private returns (bytes32, bytes32, bytes32) {
        _assertInitialized(balanceTo);
        _assertInitialized(amount);
        _assertInitialized(totalSupply);
        return getNoxCompute().mint(balanceTo, amount, totalSupply);
    }

    function _burn(
        bytes32 balanceFrom,
        bytes32 amount,
        bytes32 totalSupply
    ) private returns (bytes32, bytes32, bytes32) {
        _assertInitialized(balanceFrom);
        _assertInitialized(amount);
        _assertInitialized(totalSupply);
        return getNoxCompute().burn(balanceFrom, amount, totalSupply);
    }
}
