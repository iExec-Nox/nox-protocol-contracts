// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Common} from "../modules/Common.sol";

/**
 * @dev Storage stub for sol2uml diagram generation only.
 * Declares NoxComputeStorage at slot 0 so sol2uml can render the layout.
 * NOT deployed. The real layout lives at the ERC7201 slot in Common.sol.
 */
abstract contract NoxComputeStorageStub {
    Common.NoxComputeStorage private $;
}
