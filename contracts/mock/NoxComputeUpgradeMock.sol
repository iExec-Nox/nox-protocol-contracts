// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {NoxCompute} from "../NoxCompute.sol";

/**
 * @title NoxComputeUpgradeMock
 * @dev Mock implementation used to verify the upgrade mechanism end-to-end:
 *      swapping the proxy's implementation, preserving storage, and passing the
 *      OZ Upgrades plugin's storage-layout safety checks.
 *      Exposes an `isUpgradeMock()` marker so tests can confirm calls land on this
 *      new implementation rather than the previous one.
 */
contract NoxComputeUpgradeMock is NoxCompute {
    constructor() NoxCompute() {}

    /// @return Marker that only exists on this mock implementation; upgrade tests read it
    /// to confirm the proxy now delegates to this new implementation.
    function isUpgradeMock() external pure returns (bool) {
        return true;
    }
}
