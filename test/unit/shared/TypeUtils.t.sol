// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {
    TEEType,
    TypeUtils,
    NonArithmeticType,
    UnsupportedArithmeticType
} from "../../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";

contract TypeUtilsTest is Test {
    TEEType[4] supportedTypes = [TEEType.Uint16, TEEType.Uint256, TEEType.Int16, TEEType.Int256];

    function test_TypesLength() public pure {
        assertEq(uint8(type(TEEType).max), 100);
    }

    // ============ typeOf ============

    function test_TypeOf_ReturnsType() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Uint256);
        assertEq(uint8(TypeUtils.typeOf(handle)), uint8(TEEType.Uint256));
    }

    // ============ validateArithmeticType ============

    function test_ValidateArithmeticType() public view {
        for (uint256 i = 0; i < supportedTypes.length; i++) {
            TypeUtils.validateArithmeticType(supportedTypes[i]);
        }
    }

    function test_RevertWhen_ValidateArithmeticType_NonArithmeticType() public {
        for (uint8 i = 0; i < uint8(TEEType.String); i++) {
            vm.expectRevert(NonArithmeticType.selector);
            TypeUtils.validateArithmeticType(TEEType(i));
        }
        for (uint8 i = uint8(TEEType.Bytes1); i < uint8(type(TEEType).max); i++) {
            vm.expectRevert(NonArithmeticType.selector);
            TypeUtils.validateArithmeticType(TEEType(i));
        }
    }

    function test_RevertWhen_ValidateArithmeticType_UnsupportedArithmeticType() public {
        for (uint8 i = uint8(TEEType.Uint8); i < uint8(TEEType.Int256); i++) {
            vm.expectRevert(UnsupportedArithmeticType.selector);
            TypeUtils.validateArithmeticType(TEEType(i));
        }
    }
}
