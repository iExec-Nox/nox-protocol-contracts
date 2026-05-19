// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {INoxCompute} from "../interfaces/INoxCompute.sol";

abstract contract Common is INoxCompute {
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

    // ----- Functions used cross-modules -----

    function _getNoxComputeStorage() internal pure virtual returns (NoxComputeStorage storage $);

    function _allowTransient(bytes32 handle, address account) internal virtual;

    function _validateAllowedForAll(
        address account,
        bytes32[] memory handles
    ) internal view virtual;
}
