// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface ITEEComputeManager {
    // TODO put common errors in a shared interface.
    error InvalidZeroAddress();
    error InvalidProof(bytes proof, string reason);

    event ACLUpdated(address indexed newACL);
}
