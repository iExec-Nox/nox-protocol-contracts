// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IACL} from "./interfaces/IACL.sol";

/**
 * @title ACL
 * @notice The ACL (Access Control List) is a permission management system designed to control access rights
 * for encrypted handles within the Nox protocol. By defining administrators and delegated viewers for each handle,
 * the ACL ensures that sensitive data remains protected while enabling authorized parties to interact with
 * encrypted resources in a secure and controlled manner.
 */
contract ACL is IACL{
    /// @notice Main storage structure following ERC-7201 pattern
    struct ACLStorage {
        mapping(bytes32 => IACL.HandleInfo) handles;
        //TODO: Add TEEComputeManager Contract Address
    }

    // keccak256(abi.encode(uint256(keccak256("nox.storage.ACL")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ACL_STORAGE_LOCATION =
        0xed401488ebb59e3713b284243aa87272e78f75cf6500206003b8bf39f01abd00;

    /**
     * @notice Get the storage location for ACL data
     * @return $ The storage pointer
     */
    function _getACLStorage() private pure returns (ACLStorage storage $) {
        assembly {
            $.slot := ACL_STORAGE_LOCATION
        }
    }
}
