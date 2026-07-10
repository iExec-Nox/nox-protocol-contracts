// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Nox} from "../sdk/Nox.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";
import {TEEType} from "../utils/TypeUtils.sol";

/**
 * @title NoxTransientTestHarness
 * @dev Test-only contract that calls NoxCompute and checks transient state.
 * A public handle is registered transiently only for the transaction that wraps it, and
 * Hardhat EDR clears transient state between separate external calls made directly from a
 * Solidity test. Bundling the wrap and the subsequent check behind one call keeps them in the
 * same transaction, so the transient registration is visible to the check.
 */
contract NoxTransientTestHarness {
    function wrapAsPublicHandleAndCheckIsAllowed(
        bytes32 value,
        TEEType teeType,
        address account
    ) external returns (bool) {
        INoxCompute nox = INoxCompute(Nox.noxComputeContract());
        bytes32 handle = nox.wrapAsPublicHandle(value, teeType);
        return nox.isAllowed(handle, account);
    }

    function wrapAsPublicHandleAndValidateAllowedForAll(
        bytes32 value1,
        bytes32 value2,
        TEEType teeType,
        address account
    ) external {
        INoxCompute nox = INoxCompute(Nox.noxComputeContract());
        bytes32[] memory handles = new bytes32[](2);
        handles[0] = nox.wrapAsPublicHandle(value1, teeType);
        handles[1] = nox.wrapAsPublicHandle(value2, teeType);
        nox.validateAllowedForAll(account, handles);
    }
}
