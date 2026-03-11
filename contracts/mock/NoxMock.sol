// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "encrypted-types/EncryptedTypes.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";

/**
 * @dev Exposes Nox internal functions as external functions so that
 * vm.expectRevert can intercept reverts from sub-calls in tests.
 * Uses distinct function names to avoid ABI overload clashes: UDVTs share
 * the same underlying bytes32 type, making overloads ambiguous externally.
 */
contract NoxMock {
    // ============ Address resolution ============

    function compute() external view returns (address) {
        return Nox.noxComputeContract();
    }

    // ============ Arithmetic ============

    function addEuint16(bytes32 a, bytes32 b) external {
        Nox.add(euint16.wrap(a), euint16.wrap(b));
    }

    function addEuint256(bytes32 a, bytes32 b) external {
        Nox.add(euint256.wrap(a), euint256.wrap(b));
    }

    function addEint16(bytes32 a, bytes32 b) external {
        Nox.add(eint16.wrap(a), eint16.wrap(b));
    }

    function addEint256(bytes32 a, bytes32 b) external {
        Nox.add(eint256.wrap(a), eint256.wrap(b));
    }

    function subEuint16(bytes32 a, bytes32 b) external {
        Nox.sub(euint16.wrap(a), euint16.wrap(b));
    }

    function subEuint256(bytes32 a, bytes32 b) external {
        Nox.sub(euint256.wrap(a), euint256.wrap(b));
    }

    function subEint16(bytes32 a, bytes32 b) external {
        Nox.sub(eint16.wrap(a), eint16.wrap(b));
    }

    function subEint256(bytes32 a, bytes32 b) external {
        Nox.sub(eint256.wrap(a), eint256.wrap(b));
    }

    function mulEuint16(bytes32 a, bytes32 b) external {
        Nox.mul(euint16.wrap(a), euint16.wrap(b));
    }

    function mulEuint256(bytes32 a, bytes32 b) external {
        Nox.mul(euint256.wrap(a), euint256.wrap(b));
    }

    function mulEint16(bytes32 a, bytes32 b) external {
        Nox.mul(eint16.wrap(a), eint16.wrap(b));
    }

    function mulEint256(bytes32 a, bytes32 b) external {
        Nox.mul(eint256.wrap(a), eint256.wrap(b));
    }

    function divEuint16(bytes32 a, bytes32 b) external {
        Nox.div(euint16.wrap(a), euint16.wrap(b));
    }

    function divEuint256(bytes32 a, bytes32 b) external {
        Nox.div(euint256.wrap(a), euint256.wrap(b));
    }

    function divEint16(bytes32 a, bytes32 b) external {
        Nox.div(eint16.wrap(a), eint16.wrap(b));
    }

    function divEint256(bytes32 a, bytes32 b) external {
        Nox.div(eint256.wrap(a), eint256.wrap(b));
    }

    // ============ Safe arithmetic ============

    function safeAddEuint16(bytes32 a, bytes32 b) external {
        Nox.safeAdd(euint16.wrap(a), euint16.wrap(b));
    }

    function safeAddEuint256(bytes32 a, bytes32 b) external {
        Nox.safeAdd(euint256.wrap(a), euint256.wrap(b));
    }

    function safeAddEint16(bytes32 a, bytes32 b) external {
        Nox.safeAdd(eint16.wrap(a), eint16.wrap(b));
    }

    function safeAddEint256(bytes32 a, bytes32 b) external {
        Nox.safeAdd(eint256.wrap(a), eint256.wrap(b));
    }

    function safeSubEuint16(bytes32 a, bytes32 b) external {
        Nox.safeSub(euint16.wrap(a), euint16.wrap(b));
    }

    function safeSubEuint256(bytes32 a, bytes32 b) external {
        Nox.safeSub(euint256.wrap(a), euint256.wrap(b));
    }

    function safeSubEint16(bytes32 a, bytes32 b) external {
        Nox.safeSub(eint16.wrap(a), eint16.wrap(b));
    }

    function safeSubEint256(bytes32 a, bytes32 b) external {
        Nox.safeSub(eint256.wrap(a), eint256.wrap(b));
    }

    function safeMulEuint16(bytes32 a, bytes32 b) external {
        Nox.safeMul(euint16.wrap(a), euint16.wrap(b));
    }

    function safeMulEuint256(bytes32 a, bytes32 b) external {
        Nox.safeMul(euint256.wrap(a), euint256.wrap(b));
    }

    function safeMulEint16(bytes32 a, bytes32 b) external {
        Nox.safeMul(eint16.wrap(a), eint16.wrap(b));
    }

    function safeMulEint256(bytes32 a, bytes32 b) external {
        Nox.safeMul(eint256.wrap(a), eint256.wrap(b));
    }

    function safeDivEuint16(bytes32 a, bytes32 b) external {
        Nox.safeDiv(euint16.wrap(a), euint16.wrap(b));
    }

    function safeDivEuint256(bytes32 a, bytes32 b) external {
        Nox.safeDiv(euint256.wrap(a), euint256.wrap(b));
    }

    function safeDivEint16(bytes32 a, bytes32 b) external {
        Nox.safeDiv(eint16.wrap(a), eint16.wrap(b));
    }

    function safeDivEint256(bytes32 a, bytes32 b) external {
        Nox.safeDiv(eint256.wrap(a), eint256.wrap(b));
    }

    // ============ Select ============

    function selectEuint16(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external {
        Nox.select(ebool.wrap(condition), euint16.wrap(ifTrue), euint16.wrap(ifFalse));
    }

    function selectEuint256(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external {
        Nox.select(ebool.wrap(condition), euint256.wrap(ifTrue), euint256.wrap(ifFalse));
    }

    function selectEint16(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external {
        Nox.select(ebool.wrap(condition), eint16.wrap(ifTrue), eint16.wrap(ifFalse));
    }

    function selectEint256(bytes32 condition, bytes32 ifTrue, bytes32 ifFalse) external {
        Nox.select(ebool.wrap(condition), eint256.wrap(ifTrue), eint256.wrap(ifFalse));
    }

    // ============ Comparisons ============

    function eqEuint16(bytes32 a, bytes32 b) external {
        Nox.eq(euint16.wrap(a), euint16.wrap(b));
    }

    function eqEuint256(bytes32 a, bytes32 b) external {
        Nox.eq(euint256.wrap(a), euint256.wrap(b));
    }

    function eqEint16(bytes32 a, bytes32 b) external {
        Nox.eq(eint16.wrap(a), eint16.wrap(b));
    }

    function eqEint256(bytes32 a, bytes32 b) external {
        Nox.eq(eint256.wrap(a), eint256.wrap(b));
    }

    function neEuint16(bytes32 a, bytes32 b) external {
        Nox.ne(euint16.wrap(a), euint16.wrap(b));
    }

    function neEuint256(bytes32 a, bytes32 b) external {
        Nox.ne(euint256.wrap(a), euint256.wrap(b));
    }

    function neEint16(bytes32 a, bytes32 b) external {
        Nox.ne(eint16.wrap(a), eint16.wrap(b));
    }

    function neEint256(bytes32 a, bytes32 b) external {
        Nox.ne(eint256.wrap(a), eint256.wrap(b));
    }

    function ltEuint16(bytes32 a, bytes32 b) external {
        Nox.lt(euint16.wrap(a), euint16.wrap(b));
    }

    function ltEuint256(bytes32 a, bytes32 b) external {
        Nox.lt(euint256.wrap(a), euint256.wrap(b));
    }

    function ltEint16(bytes32 a, bytes32 b) external {
        Nox.lt(eint16.wrap(a), eint16.wrap(b));
    }

    function ltEint256(bytes32 a, bytes32 b) external {
        Nox.lt(eint256.wrap(a), eint256.wrap(b));
    }

    function leEuint16(bytes32 a, bytes32 b) external {
        Nox.le(euint16.wrap(a), euint16.wrap(b));
    }

    function leEuint256(bytes32 a, bytes32 b) external {
        Nox.le(euint256.wrap(a), euint256.wrap(b));
    }

    function leEint16(bytes32 a, bytes32 b) external {
        Nox.le(eint16.wrap(a), eint16.wrap(b));
    }

    function leEint256(bytes32 a, bytes32 b) external {
        Nox.le(eint256.wrap(a), eint256.wrap(b));
    }

    function gtEuint16(bytes32 a, bytes32 b) external {
        Nox.gt(euint16.wrap(a), euint16.wrap(b));
    }

    function gtEuint256(bytes32 a, bytes32 b) external {
        Nox.gt(euint256.wrap(a), euint256.wrap(b));
    }

    function gtEint16(bytes32 a, bytes32 b) external {
        Nox.gt(eint16.wrap(a), eint16.wrap(b));
    }

    function gtEint256(bytes32 a, bytes32 b) external {
        Nox.gt(eint256.wrap(a), eint256.wrap(b));
    }

    function geEuint16(bytes32 a, bytes32 b) external {
        Nox.ge(euint16.wrap(a), euint16.wrap(b));
    }

    function geEuint256(bytes32 a, bytes32 b) external {
        Nox.ge(euint256.wrap(a), euint256.wrap(b));
    }

    function geEint16(bytes32 a, bytes32 b) external {
        Nox.ge(eint16.wrap(a), eint16.wrap(b));
    }

    function geEint256(bytes32 a, bytes32 b) external {
        Nox.ge(eint256.wrap(a), eint256.wrap(b));
    }

    // ============ fromExternal ============

    function fromExternalEbool(
        externalEbool handle,
        bytes calldata proof
    ) external returns (ebool) {
        return Nox.fromExternal(handle, proof);
    }

    function fromExternalEaddress(
        externalEaddress handle,
        bytes calldata proof
    ) external returns (eaddress) {
        return Nox.fromExternal(handle, proof);
    }

    function fromExternalEuint16(
        externalEuint16 handle,
        bytes calldata proof
    ) external returns (euint16) {
        return Nox.fromExternal(handle, proof);
    }

    function fromExternalEuint256(
        externalEuint256 handle,
        bytes calldata proof
    ) external returns (euint256) {
        return Nox.fromExternal(handle, proof);
    }

    function fromExternalEint16(
        externalEint16 handle,
        bytes calldata proof
    ) external returns (eint16) {
        return Nox.fromExternal(handle, proof);
    }

    function fromExternalEint256(
        externalEint256 handle,
        bytes calldata proof
    ) external returns (eint256) {
        return Nox.fromExternal(handle, proof);
    }

    // ============ Public decrypt ============

    function publicDecryptEbool(bytes32 handle, bytes calldata proof) external returns (bool) {
        return Nox.publicDecrypt(ebool.wrap(handle), proof);
    }

    function publicDecryptEaddress(
        bytes32 handle,
        bytes calldata proof
    ) external returns (address) {
        return Nox.publicDecrypt(eaddress.wrap(handle), proof);
    }

    function publicDecryptEuint16(bytes32 handle, bytes calldata proof) external returns (uint16) {
        return Nox.publicDecrypt(euint16.wrap(handle), proof);
    }

    function publicDecryptEuint256(
        bytes32 handle,
        bytes calldata proof
    ) external returns (uint256) {
        return Nox.publicDecrypt(euint256.wrap(handle), proof);
    }

    function publicDecryptEint16(bytes32 handle, bytes calldata proof) external returns (int16) {
        return Nox.publicDecrypt(eint16.wrap(handle), proof);
    }

    function publicDecryptEint256(bytes32 handle, bytes calldata proof) external returns (int256) {
        return Nox.publicDecrypt(eint256.wrap(handle), proof);
    }

    // ============ Advanced ============

    function transfer(bytes32 balanceFrom, bytes32 balanceTo, bytes32 amount) external {
        Nox.transfer(euint256.wrap(balanceFrom), euint256.wrap(balanceTo), euint256.wrap(amount));
    }

    function mint(bytes32 balanceTo, bytes32 amount, bytes32 totalSupply) external {
        Nox.mint(euint256.wrap(balanceTo), euint256.wrap(amount), euint256.wrap(totalSupply));
    }

    function burn(bytes32 balanceFrom, bytes32 amount, bytes32 totalSupply) external {
        Nox.burn(euint256.wrap(balanceFrom), euint256.wrap(amount), euint256.wrap(totalSupply));
    }
}
