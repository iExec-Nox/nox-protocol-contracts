// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {NoxCompute} from "../NoxCompute.sol";

/**
 * @title NoxComputeV2Mock
 * @dev Mock V2 implementation of NoxCompute for testing upgrades.
 * Adds a version() function to verify the upgrade was applied.
 */
contract NoxComputeV2Mock is NoxCompute {
    /**
     * Returns the contract version.
     * @return The version number (2 for the V2 mock)
     */
    function version() external pure returns (uint256) {
        return 2;
    }
}
