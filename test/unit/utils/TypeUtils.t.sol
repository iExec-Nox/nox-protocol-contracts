// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {
    TEEType,
    TypeUtils,
    NonArithmeticType,
    UnsupportedArithmeticType
} from "../../../contracts/utils/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";

contract TypeUtilsTest is Test {
    TypeUtilsMock private typeUtilsMock = new TypeUtilsMock();
    TEEType[4] supportedTypes = [TEEType.Uint16, TEEType.Uint256, TEEType.Int16, TEEType.Int256];

    function test_TypesLength() public pure {
        assertEq(uint8(type(TEEType).max), 99);
    }

    // ============ typeOf ============

    function test_TypeOf_ReturnsType() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Uint256);
        assertEq(uint8(typeUtilsMock.typeOf(handle)), uint8(TEEType.Uint256));
    }

    // ============ validateArithmeticType ============

    function test_ValidateArithmeticType() public view {
        for (uint256 i = 0; i < supportedTypes.length; i++) {
            typeUtilsMock.validateArithmeticType(supportedTypes[i]);
        }
    }

    function test_RevertWhen_ValidateArithmeticType_NonArithmeticType() public {
        for (uint8 i = 0; i < uint8(TEEType.Uint8); i++) {
            vm.expectRevert(NonArithmeticType.selector);
            typeUtilsMock.validateArithmeticType(TEEType(i));
        }
        for (uint8 i = uint8(TEEType.Bytes1); i <= uint8(type(TEEType).max); i++) {
            vm.expectRevert(NonArithmeticType.selector);
            typeUtilsMock.validateArithmeticType(TEEType(i));
        }
    }

    function test_RevertWhen_ValidateArithmeticType_UnsupportedArithmeticType() public {
        for (uint8 i = uint8(TEEType.Uint8); i <= uint8(TEEType.Int256); i++) {
            if (_supportedType(TEEType(i))) {
                continue;
            }
            vm.expectRevert(UnsupportedArithmeticType.selector);
            typeUtilsMock.validateArithmeticType(TEEType(i));
        }
    }

    function _supportedType(TEEType teeType) private view returns (bool) {
        for (uint256 i = 0; i < supportedTypes.length; i++) {
            if (teeType == supportedTypes[i]) {
                return true;
            }
        }
        return false;
    }
}

/**
 * Mock contract to test revert scenarios of TypeUtils library.
 */
contract TypeUtilsMock {
    function typeOf(bytes32 handle) public pure returns (TEEType) {
        return TypeUtils.typeOf(handle);
    }

    function validateArithmeticType(TEEType teeType) public pure {
        TypeUtils.validateArithmeticType(teeType);
    }
}
