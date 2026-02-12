// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "encrypted-types/EncryptedTypes.sol";
import {Nox} from "../../contracts/sdk/Nox.sol";

/**
 * This contract is used to call the `fromExternal` function with calldata bytes.
 * We cannot call `Nox.fromExternal(handle, proof)` directly because the proof
 * would have the type `bytes memory`, which is incompatible with the `bytes calldata`
 * in the function signature.
 */
contract NoxFromExternalMock {
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

    function fromExternalEint256(
        externalEint256 handle,
        bytes calldata proof
    ) external returns (eint256) {
        return Nox.fromExternal(handle, proof);
    }
}
