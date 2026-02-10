// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "encrypted-types/EncryptedTypes.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ACL} from "../../contracts/ACL.sol";
import {IACL} from "../../contracts/interfaces/IACL.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {TEEType} from "../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";
import {IErrors} from "../../contracts/interfaces/IErrors.sol";
import {TEEPrimitives} from "../../contracts/lib/TEEPrimitives.sol";

// Note: these tests are here to make sure the library calls the correct
// functions on the TEEComputeManager and ACL, and that the `isInitialized`
// function works as expected. The actual logic of those functions is tested
// in the TEEComputeManager and ACL tests, so we can keep these tests
// relatively light.

contract TEEPrimitivesTest is Test {
    address owner = makeAddr("owner");
    address account = makeAddr("account");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    ACL aclContract;
    TEEComputeManager teeComputeManagerContract;
    address acl;
    address teeComputeManager;
    uint256 createdAt = block.timestamp;
    bytes32 handleA = TestHelper.createHandle(TEEType.Uint256);
    bytes32 handleB = TestHelper.createHandle(TEEType.Uint256);

    function setUp() public {
        (aclContract, teeComputeManagerContract) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        teeComputeManager = address(teeComputeManagerContract);
        TEEPrimitives.setNoxConfig(teeComputeManager);
        _allowCaller(handleA);
        _allowCaller(handleB);
        vm.label(account, "account");
    }

    // ============ isInitialized ============

    function test_isInitialized_ShouldReturnTrueForNonZeroValues() public pure {
        assertTrue(TEEPrimitives.isInitialized(euint256.wrap(bytes32(uint256(1)))));
        assertTrue(TEEPrimitives.isInitialized(eint256.wrap(bytes32(uint256(1)))));
    }

    function test_isInitialized_ShouldReturnFalseForZeroValues() public pure {
        assertFalse(TEEPrimitives.isInitialized(euint256.wrap(0)));
        assertFalse(TEEPrimitives.isInitialized(eint256.wrap(0)));
    }

    // ============ toEbool ============

    function test_toEbool_True() public {
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.plaintextToEncrypted, (1, TEEType.Bool))
        );
        ebool result = TEEPrimitives.toEbool(true);
        assertNotEq(ebool.unwrap(result), 0);
    }

    function test_toEbool_False() public {
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.plaintextToEncrypted, (0, TEEType.Bool))
        );
        ebool result = TEEPrimitives.toEbool(false);
        assertNotEq(ebool.unwrap(result), 0);
    }

    // ============ toEaddress ============

    function test_toEaddress() public {
        address testAddress = address(0x1234567890123456789012345678901234567890);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(
                ITEEComputeManager.plaintextToEncrypted,
                (uint256(uint160(testAddress)), TEEType.Address)
            )
        );
        eaddress result = TEEPrimitives.toEaddress(testAddress);
        assertNotEq(eaddress.unwrap(result), 0);
    }

    // ============ toEuint256 ============

    function test_toEuint256() public {
        uint256 value = 12345;
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.plaintextToEncrypted, (value, TEEType.Uint256))
        );
        euint256 result = TEEPrimitives.toEuint256(value);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ toEint256 ============

    function test_toEint256() public {
        int256 value = -12345;
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(
                ITEEComputeManager.plaintextToEncrypted,
                (uint256(value), TEEType.Int256)
            )
        );
        eint256 result = TEEPrimitives.toEint256(value);
        assertNotEq(eint256.unwrap(result), 0);
    }

    // ============ fromExternal ============

    // TODO function test_fromExternal() public {}

    // ============ add ============

    function test_add() public {
        euint256 a = euint256.wrap(handleA);
        euint256 b = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.add, (handleA, handleB))
        );
        euint256 result = TEEPrimitives.add(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ sub ============

    function test_sub() public {
        euint256 a = euint256.wrap(handleA);
        euint256 b = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.sub, (handleA, handleB))
        );
        euint256 result = TEEPrimitives.sub(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ mul ============

    function test_mul() public {
        euint256 a = euint256.wrap(handleA);
        euint256 b = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.mul, (handleA, handleB))
        );
        euint256 result = TEEPrimitives.mul(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ div ============

    function test_div() public {
        euint256 a = euint256.wrap(handleA);
        euint256 b = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.div, (handleA, handleB))
        );
        euint256 result = TEEPrimitives.div(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ safeAdd ============

    function test_safeAdd() public {
        euint256 a = euint256.wrap(handleA);
        euint256 b = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.safeAdd, (handleA, handleB))
        );
        (ebool success, euint256 result) = TEEPrimitives.safeAdd(a, b);
        assertNotEq(ebool.unwrap(success), 0);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ safeSub ============

    function test_safeSub() public {
        euint256 a = euint256.wrap(handleA);
        euint256 b = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.safeSub, (handleA, handleB))
        );
        (ebool success, euint256 result) = TEEPrimitives.safeSub(a, b);
        assertNotEq(ebool.unwrap(success), 0);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ select ============

    function test_select() public {
        bytes32 conditionHandle = TestHelper.createHandle(TEEType.Bool);
        _allowCaller(conditionHandle);
        ebool condition = ebool.wrap(conditionHandle);
        euint256 ifTrue = euint256.wrap(handleA);
        euint256 ifFalse = euint256.wrap(handleB);
        vm.expectCall(
            teeComputeManager,
            abi.encodeCall(ITEEComputeManager.select, (conditionHandle, handleA, handleB))
        );
        euint256 result = TEEPrimitives.select(condition, ifTrue, ifFalse);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ allow(ebool) ============

    function test_allow_ebool() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Bool);
        _allowCaller(handle);
        ebool value = ebool.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handle, account)));
        TEEPrimitives.allow(value, account);
    }

    // ============ allow(eaddress) ============

    function test_allow_eaddress() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Address);
        _allowCaller(handle);
        eaddress value = eaddress.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handle, account)));
        TEEPrimitives.allow(value, account);
    }

    // ============ allow(euint256) ============

    function test_allow_euint256() public {
        euint256 value = euint256.wrap(handleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handleA, account)));
        TEEPrimitives.allow(value, account);
    }

    // ============ allow(eint256) ============

    function test_allow_eint256() public {
        eint256 value = eint256.wrap(handleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handleA, account)));
        TEEPrimitives.allow(value, account);
    }

    // ============ allowThis(ebool) ============

    function test_allowThis_ebool() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Bool);
        _allowCaller(handle);
        ebool value = ebool.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handle, address(this))));
        TEEPrimitives.allowThis(value);
    }

    // ============ allowThis(euint256) ============

    function test_allowThis_euint256() public {
        euint256 value = euint256.wrap(handleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handleA, address(this))));
        TEEPrimitives.allowThis(value);
    }

    // ============ allowThis(eint256) ============

    function test_allowThis_eint256() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Int256);
        _allowCaller(handle);
        eint256 value = eint256.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handle, address(this))));
        TEEPrimitives.allowThis(value);
    }

    // ============ allowThis(eaddress) ============

    function test_allowThis_eaddress() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Address);
        _allowCaller(handle);
        eaddress value = eaddress.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (handle, address(this))));
        TEEPrimitives.allowThis(value);
    }

    // ============ allowTransient(ebool) ============

    function test_allowTransient_ebool() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Bool);
        _allowCaller(handle);
        ebool value = ebool.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (handle, account)));
        TEEPrimitives.allowTransient(value, account);
    }

    // ============ allowTransient(eaddress) ============

    function test_allowTransient_eaddress() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Address);
        _allowCaller(handle);
        eaddress value = eaddress.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (handle, account)));
        TEEPrimitives.allowTransient(value, account);
    }

    // ============ allowTransient(euint256) ============

    function test_allowTransient_euint256() public {
        euint256 value = euint256.wrap(handleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (handleA, account)));
        TEEPrimitives.allowTransient(value, account);
    }

    // ============ allowTransient(eint256) ============

    function test_allowTransient_eint256() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Int256);
        _allowCaller(handle);
        eint256 value = eint256.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (handle, account)));
        TEEPrimitives.allowTransient(value, account);
    }

    // ============ allowPublicDecryption(ebool) ============

    function test_allowPublicDecryption_ebool() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Bool);
        _allowCaller(handle);
        ebool value = ebool.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (handle)));
        TEEPrimitives.allowPublicDecryption(value);
    }

    // ============ allowPublicDecryption(eaddress) ============

    function test_allowPublicDecryption_eaddress() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Address);
        _allowCaller(handle);
        eaddress value = eaddress.wrap(handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (handle)));
        TEEPrimitives.allowPublicDecryption(value);
    }

    // ============ allowPublicDecryption(euint256) ============

    function test_allowPublicDecryption_euint256() public {
        euint256 value = euint256.wrap(handleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (handleA)));
        TEEPrimitives.allowPublicDecryption(value);
    }

    // ============ allowPublicDecryption(eint256) ============

    function test_allowPublicDecryption_eint256() public {
        bytes32 handle = TestHelper.createHandle(TEEType.Int256);
        _allowCaller(handle);
        eint256 value = eint256.wrap(handle);

        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (handle)));
        TEEPrimitives.allowPublicDecryption(value);
    }

    // ============ isAllowed ============

    function test_isAllowed() public {
        euint256 value = euint256.wrap(handleA);
        vm.expectCall(acl, abi.encodeCall(IACL.isAllowed, (handleA, account)));
        TEEPrimitives.isAllowed(value, account);
    }

    /**
     * Helper function to allow this test contract as a caller of the given handle.
     */
    function _allowCaller(bytes32 handle) internal {
        vm.startPrank(teeComputeManager);
        aclContract.allowTransient(handle, address(this));
        vm.stopPrank();
        aclContract.allow(handle, address(this));
    }
}
