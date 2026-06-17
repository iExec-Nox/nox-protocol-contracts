// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Common
 * @notice Shared base for all modules. Declares the ERC7201-namespaced state variables
 * (layout managed by NoxCompute via `layout at erc7201(...)`) and virtual declarations
 * for cross-module functions.
 */
abstract contract Common is INoxCompute {
    // An admin of a handle can:
    //  - use it as a computation input
    //  - decrypt its associated data off-chain
    //  - make it publicly decryptable
    //  - add other admins and viewers
    mapping(bytes32 handleId => mapping(address => bool)) internal _admins;
    // A viewer of a handle can only decrypt its associated data off-chain.
    mapping(bytes32 handleId => mapping(address => bool)) internal _viewers;
    // Handles that are publicly decryptable
    mapping(bytes32 handle => bool) internal _isPubliclyDecryptable;
    bytes internal _kmsPublicKey;
    address internal _gateway;
    uint256 internal _proofExpirationDuration;
    // Counter used to guarantee handle uniqueness when all operands are public handles
    uint256 internal _uniqueSeedCounter;

    // ----- Functions used cross-modules -----

    // Implemented by ACL, called by Compute.
    function _allowTransient(bytes32 handle, address account) internal virtual;

    // Implemented by ACL, called by Compute.
    function _validateAllowedForAll(
        address account,
        bytes32[] memory handles
    ) internal view virtual;
}
