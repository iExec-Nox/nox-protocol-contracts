// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IACL} from "../interfaces/IACL.sol";

/**
 * @title MockACL
 * @notice Mock ACL contract for testing TEEComputeManager
 */
contract MockACL {
    mapping(bytes32 => mapping(address => bool)) private _allowed;

    function setAllowed(bytes32 handle, address account, bool allowed) external {
        _allowed[handle][account] = allowed;
    }

    function isAllowed(bytes32 handle, address account) external view returns (bool) {
        return _allowed[handle][account];
    }

    function allowTransient(bytes32, address) external pure {}
}
