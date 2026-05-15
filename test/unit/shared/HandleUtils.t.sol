// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TEEType, TypeUtils} from "../../../contracts/shared/TypeUtils.sol";
import {HandleUtils} from "../../../contracts/shared/HandleUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";

contract HandleUtilsTest is Test {
    // ============ isPublicHandle ============

    function test_IsPublicHandle_ReturnsTrue() public {
        bytes32 handle = TestHelper.createPublicHandle(TEEType.Uint256);
        assertTrue(HandleUtils.isPublicHandle(handle));
    }

    function test_IsPublicHandle_ReturnsFalse() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Uint256);
        assertFalse(HandleUtils.isPublicHandle(handle));
    }

    // ============ zeroHandle ============

    function test_ZeroHandle() public view {
        bytes32 handle = HandleUtils.zeroHandle(TEEType.Int256);
        bytes32 expectedHandle = bytes32(
            abi.encodePacked(
                bytes1(0x00),
                bytes4(uint32(block.chainid)),
                bytes1(uint8(TEEType.Int256)),
                bytes1(0x00),
                bytes25(0)
            )
        );
        assertEq(handle, expectedHandle);
        assertEq(uint8(TypeUtils.typeOf(handle)), uint8(TEEType.Int256));
        assertTrue(HandleUtils.isPublicHandle(handle));
    }
}
