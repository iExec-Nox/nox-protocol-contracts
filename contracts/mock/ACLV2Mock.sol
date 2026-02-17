// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ACL} from "../ACL.sol";

/**
 * @title ACLV2Mock
 * @dev Mock V2 implementation of ACL for testing upgrades.
 * Adds a version() function to verify the upgrade was applied.
 */
contract ACLV2Mock is ACL {
    /**
     * Returns the contract version.
     * @return The version number (2 for the V2 mock)
     */
    function version() external pure returns (uint256) {
        return 2;
    }
}
