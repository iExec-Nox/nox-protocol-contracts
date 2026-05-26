// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {NoxCompute} from "../NoxCompute.sol";

/**
 * @title NoxComputeUpgradeMock
 * @dev Mock implementation used to verify the upgrade mechanism end-to-end:
 *      swapping the proxy's implementation, preserving storage, and passing the
 *      OZ Upgrades plugin's storage-layout safety checks.
 *      Exposes a `version()` sentinel so tests can confirm calls land on this
 *      new implementation rather than the previous one.
 */
contract NoxComputeUpgradeMock is NoxCompute {
    constructor(uint8 cuPerOperation) NoxCompute(cuPerOperation) {}

    /// @return Sentinel version number used by upgrade tests to detect the impl swap.
    /// @dev Bump this value whenever a new `initialize*` is added to `NoxCompute` so the
    /// sentinel stays aligned with the latest reinitializer version.
    function version() external pure returns (uint256) {
        return 3;
    }
}
