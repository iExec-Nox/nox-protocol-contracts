// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {
    TEEType,
    TypeUtils,
    InvalidType,
    UnsupportedArithmeticType,
    UnsupportedType,
    IncompatibleTypes,
    ValueOutOfRange
} from "../../../contracts/utils/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";

contract TypeUtilsTest is Test {
    TypeUtilsMock private typeUtilsMock = new TypeUtilsMock();
    TEEType[4] supportedTypes = [TEEType.Uint16, TEEType.Uint256, TEEType.Int16, TEEType.Int256];
    TEEType[5] allSupportedTypes = [
        TEEType.Bool,
        TEEType.Uint16,
        TEEType.Uint256,
        TEEType.Int16,
        TEEType.Int256
    ];

    function test_TypesLength() public pure {
        assertEq(uint8(type(TEEType).max), 99);
    }

    // ============ typeOf ============

    function test_TypeOf_ReturnsType() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Uint256);
        assertEq(uint8(typeUtilsMock.typeOf(handle)), uint8(TEEType.Uint256));
    }

    // ============ isSupportedType ============

    function test_IsSupportedType() public view {
        for (uint8 i = 0; i <= uint8(type(TEEType).max); i++) {
            bool isSupported = _inAllSupportedTypes(TEEType(i));
            assertEq(typeUtilsMock.isSupportedType(TEEType(i)), isSupported);
        }
    }

    // ============ isSupportedArithmeticType ============

    function test_IsSupportedArithmeticType() public view {
        for (uint8 i = 0; i <= uint8(type(TEEType).max); i++) {
            bool isSupported = _supportedType(TEEType(i));
            assertEq(typeUtilsMock.isSupportedArithmeticType(TEEType(i)), isSupported);
        }
    }

    // ============ validateSupportedType ============

    function test_ValidateSupportedType() public view {
        for (uint256 i = 0; i < allSupportedTypes.length; i++) {
            typeUtilsMock.validateSupportedType(allSupportedTypes[i]);
        }
    }

    function test_RevertWhen_ValidateSupportedType_UnsupportedType() public {
        for (uint8 i = 0; i <= uint8(type(TEEType).max); i++) {
            if (_inAllSupportedTypes(TEEType(i))) {
                continue;
            }
            vm.expectRevert(abi.encodeWithSelector(UnsupportedType.selector, i));
            typeUtilsMock.validateSupportedType(TEEType(i));
        }
    }

    // ============ validateSupportedArithmeticType ============

    function test_ValidateSupportedArithmeticType() public view {
        for (uint256 i = 0; i < supportedTypes.length; i++) {
            typeUtilsMock.validateSupportedArithmeticType(supportedTypes[i]);
        }
    }

    function test_RevertWhen_ValidateSupportedArithmeticType_UnsupportedArithmeticType() public {
        for (uint8 i = 0; i <= uint8(type(TEEType).max); i++) {
            if (_supportedType(TEEType(i))) {
                continue;
            }
            vm.expectRevert(UnsupportedArithmeticType.selector);
            typeUtilsMock.validateSupportedArithmeticType(TEEType(i));
        }
    }

    // ============ requireType ============

    function test_RequireType() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Uint256);
        typeUtilsMock.requireType(handle, TEEType.Uint256);
    }

    function test_RevertWhen_RequireType_IncompatibleTypes() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Uint256);
        vm.expectRevert(IncompatibleTypes.selector);
        typeUtilsMock.requireType(handle, TEEType.Int16);
    }

    function test_RevertWhen_RequireType_InvalidHandleType() public {
        uint8 badTypeIndex = uint8(type(TEEType).max) + 1;
        bytes32 badHandle = bytes32(
            abi.encodePacked(
                bytes1(0x00), // Version
                bytes4(uint32(block.chainid)), // ChainId
                bytes1(badTypeIndex), // Out-of-range type
                bytes1(0x01), // Attributes (isUniqueHandle=1)
                bytes25(uint200(1)) // Pre-handle
            )
        );
        vm.expectRevert(abi.encodeWithSelector(InvalidType.selector, badTypeIndex));
        typeUtilsMock.requireType(badHandle, TEEType.Uint256);
    }

    // ============ validateValueFitsType ============

    function test_ValidateValueFitsType() public view {
        // Bool
        typeUtilsMock.validateValueFitsType(bytes32(uint256(0)), TEEType.Bool);
        typeUtilsMock.validateValueFitsType(bytes32(uint256(1)), TEEType.Bool);
        // uint16
        typeUtilsMock.validateValueFitsType(bytes32(uint256(type(uint16).max)), TEEType.Uint16);
        // int16
        typeUtilsMock.validateValueFitsType(bytes32(uint256(type(uint16).max)), TEEType.Int16);
        // uint256
        typeUtilsMock.validateValueFitsType(bytes32(type(uint256).max), TEEType.Uint256);
        // int256
        typeUtilsMock.validateValueFitsType(bytes32(type(uint256).max), TEEType.Int256);
    }

    function test_RevertWhen_ValidateValueFitsType_InvalidValue() public {
        // Bool
        vm.expectRevert(ValueOutOfRange.selector);
        typeUtilsMock.validateValueFitsType(bytes32(uint256(2)), TEEType.Bool);
        // uint16
        vm.expectRevert(ValueOutOfRange.selector);
        typeUtilsMock.validateValueFitsType(bytes32(uint256(type(uint16).max) + 1), TEEType.Uint16);
        // int16
        vm.expectRevert(ValueOutOfRange.selector);
        typeUtilsMock.validateValueFitsType(bytes32(uint256(type(uint16).max) + 1), TEEType.Int16);
        // uint256 and int256 don't revert.
    }

    function test_ValidateValueFitsType_RevertWhen_UnsupportedType() public {
        vm.expectRevert(abi.encodeWithSelector(UnsupportedType.selector, TEEType.Uint8));
        typeUtilsMock.validateValueFitsType(bytes32((uint256(3))), TEEType.Uint8);
    }

    // TODO rename to `_supportedArithmeticType`
    function _supportedType(TEEType teeType) private view returns (bool) {
        for (uint256 i = 0; i < supportedTypes.length; i++) {
            if (teeType == supportedTypes[i]) {
                return true;
            }
        }
        return false;
    }

    function _inAllSupportedTypes(TEEType teeType) private view returns (bool) {
        for (uint256 i = 0; i < allSupportedTypes.length; i++) {
            if (teeType == allSupportedTypes[i]) {
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

    function validateSupportedArithmeticType(TEEType teeType) public pure {
        TypeUtils.validateSupportedArithmeticType(teeType);
    }

    function isSupportedType(TEEType teeType) public pure returns (bool) {
        return TypeUtils.isSupportedType(teeType);
    }

    function isSupportedArithmeticType(TEEType teeType) public pure returns (bool) {
        return TypeUtils.isSupportedArithmeticType(teeType);
    }

    function validateSupportedType(TEEType teeType) public pure {
        TypeUtils.validateSupportedType(teeType);
    }

    function requireType(bytes32 handle, TEEType expected) public pure {
        TypeUtils.requireType(handle, expected);
    }

    function validateValueFitsType(bytes32 value, TEEType teeType) public pure {
        TypeUtils.validateValueFitsType(value, teeType);
    }
}
