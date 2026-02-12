// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "encrypted-types/EncryptedTypes.sol";
import {IACL} from "../../../contracts/interfaces/IACL.sol";
import {INoxCompute} from "../../../contracts/interfaces/INoxCompute.sol";
import {TEEType} from "../../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";
import {Nox} from "../../../contracts/sdk/Nox.sol";

// Note: these tests are here to make sure the library calls the correct
// functions on the NoxCompute and ACL, and that the `isInitialized`
// function works as expected. The actual logic of most functions is tested
// in the NoxCompute and ACL tests, so we can keep these tests
// relatively light.

contract NoxTest is Test {
    address owner = makeAddr("owner");
    address account = makeAddr("account");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    IACL aclContract;
    INoxCompute noxComputeContract;
    address acl;
    address noxCompute;
    bytes32 boolHandle = TestHelper.createHandle(TEEType.Bool);
    bytes32 addressHandle = TestHelper.createHandle(TEEType.Address);
    bytes32 int256Handle = TestHelper.createHandle(TEEType.Int256);
    bytes32 uint256HandleA = TestHelper.createHandle(TEEType.Uint256);
    bytes32 uint256HandleB = TestHelper.createHandle(TEEType.Uint256);

    function setUp() public {
        (aclContract, noxComputeContract) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        noxCompute = address(noxComputeContract);
        _allowCaller(boolHandle);
        _allowCaller(addressHandle);
        _allowCaller(uint256HandleA);
        _allowCaller(uint256HandleB);
        _allowCaller(int256Handle);
        vm.label(account, "account");
    }

    // ============ isInitialized ============

    function test_isInitialized_True() public view {
        assertTrue(Nox.isInitialized(ebool.wrap(boolHandle)));
        assertTrue(Nox.isInitialized(eaddress.wrap(addressHandle)));
        assertTrue(Nox.isInitialized(euint256.wrap(uint256HandleA)));
        assertTrue(Nox.isInitialized(eint256.wrap(int256Handle)));
    }

    function test_isInitialized_False() public pure {
        assertFalse(Nox.isInitialized(ebool.wrap(0)));
        assertFalse(Nox.isInitialized(eaddress.wrap(0)));
        assertFalse(Nox.isInitialized(euint256.wrap(0)));
        assertFalse(Nox.isInitialized(eint256.wrap(0)));
    }

    // ============ to<Type> ============

    function test_toEbool_True() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (1, TEEType.Bool))
        );
        ebool result = Nox.toEbool(true);
        assertNotEq(ebool.unwrap(result), 0);
    }

    function test_toEbool_False() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (0, TEEType.Bool))
        );
        ebool result = Nox.toEbool(false);
        assertNotEq(ebool.unwrap(result), 0);
    }

    function test_toEaddress() public {
        address testAddress = address(0x1234567890123456789012345678901234567890);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(
                INoxCompute.plaintextToEncrypted,
                (uint256(uint160(testAddress)), TEEType.Address)
            )
        );
        eaddress result = Nox.toEaddress(testAddress);
        assertNotEq(eaddress.unwrap(result), 0);
    }

    function test_toEuint256() public {
        uint256 value = 12345;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (value, TEEType.Uint256))
        );
        euint256 result = Nox.toEuint256(value);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_toEint256() public {
        int256 value = -12345;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (uint256(value), TEEType.Int256))
        );
        eint256 result = Nox.toEint256(value);
        assertNotEq(eint256.unwrap(result), 0);
    }

    // ============ fromExternal ============

    // TODO function test_fromExternal() public {}

    // ============ Unsafe Arithmetic primitives ============

    function test_add() public {
        euint256 a = euint256.wrap(uint256HandleA);
        euint256 b = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.add, (uint256HandleA, uint256HandleB))
        );
        euint256 result = Nox.add(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_sub() public {
        euint256 a = euint256.wrap(uint256HandleA);
        euint256 b = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.sub, (uint256HandleA, uint256HandleB))
        );
        euint256 result = Nox.sub(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_mul() public {
        euint256 a = euint256.wrap(uint256HandleA);
        euint256 b = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.mul, (uint256HandleA, uint256HandleB))
        );
        euint256 result = Nox.mul(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_div() public {
        euint256 a = euint256.wrap(uint256HandleA);
        euint256 b = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.div, (uint256HandleA, uint256HandleB))
        );
        euint256 result = Nox.div(a, b);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ Safe arithmetic primitives ============

    function test_safeAdd() public {
        euint256 a = euint256.wrap(uint256HandleA);
        euint256 b = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.safeAdd, (uint256HandleA, uint256HandleB))
        );
        (ebool success, euint256 result) = Nox.safeAdd(a, b);
        assertNotEq(ebool.unwrap(success), 0);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_safeSub() public {
        euint256 a = euint256.wrap(uint256HandleA);
        euint256 b = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.safeSub, (uint256HandleA, uint256HandleB))
        );
        (ebool success, euint256 result) = Nox.safeSub(a, b);
        assertNotEq(ebool.unwrap(success), 0);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ select ============

    function test_select() public {
        ebool condition = ebool.wrap(boolHandle);
        euint256 ifTrue = euint256.wrap(uint256HandleA);
        euint256 ifFalse = euint256.wrap(uint256HandleB);
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.select, (boolHandle, uint256HandleA, uint256HandleB))
        );
        euint256 result = Nox.select(condition, ifTrue, ifFalse);
        assertNotEq(euint256.unwrap(result), 0);
    }

    // ============ allow(<type>) ============

    function test_allow_ebool() public {
        ebool value = ebool.wrap(boolHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (boolHandle, account)));
        Nox.allow(value, account);
    }

    function test_allow_eaddress() public {
        eaddress value = eaddress.wrap(addressHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (addressHandle, account)));
        Nox.allow(value, account);
    }

    function test_allow_euint256() public {
        euint256 value = euint256.wrap(uint256HandleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (uint256HandleA, account)));
        Nox.allow(value, account);
    }

    function test_allow_eint256() public {
        eint256 value = eint256.wrap(int256Handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (int256Handle, account)));
        Nox.allow(value, account);
    }

    // ============ allowThis(<type>) ============

    function test_allowThis_ebool() public {
        ebool value = ebool.wrap(boolHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (boolHandle, address(this))));
        Nox.allowThis(value);
    }

    function test_allowThis_euint256() public {
        euint256 value = euint256.wrap(uint256HandleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (uint256HandleA, address(this))));
        Nox.allowThis(value);
    }

    function test_allowThis_eint256() public {
        eint256 value = eint256.wrap(int256Handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (int256Handle, address(this))));
        Nox.allowThis(value);
    }

    function test_allowThis_eaddress() public {
        eaddress value = eaddress.wrap(addressHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allow, (addressHandle, address(this))));
        Nox.allowThis(value);
    }

    // ============ allowTransient(<type>) ============

    function test_allowTransient_ebool() public {
        ebool value = ebool.wrap(boolHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (boolHandle, account)));
        Nox.allowTransient(value, account);
    }

    function test_allowTransient_eaddress() public {
        eaddress value = eaddress.wrap(addressHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (addressHandle, account)));
        Nox.allowTransient(value, account);
    }

    function test_allowTransient_euint256() public {
        euint256 value = euint256.wrap(uint256HandleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (uint256HandleA, account)));
        Nox.allowTransient(value, account);
    }

    function test_allowTransient_eint256() public {
        eint256 value = eint256.wrap(int256Handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (int256Handle, account)));
        Nox.allowTransient(value, account);
    }

    // ============ isAllowed(<type>) ============

    function test_IsAllowed_Ebool() public {
        ebool value = ebool.wrap(boolHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.isAllowed, (boolHandle, account)));
        Nox.isAllowed(value, account);
    }

    function test_IsAllowed_Eaddress() public {
        eaddress value = eaddress.wrap(addressHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.isAllowed, (addressHandle, account)));
        Nox.isAllowed(value, account);
    }

    function test_IsAllowed_Euint256() public {
        euint256 value = euint256.wrap(uint256HandleA);
        vm.expectCall(acl, abi.encodeCall(IACL.isAllowed, (uint256HandleA, account)));
        Nox.isAllowed(value, account);
    }

    function test_IsAllowed_Eint256() public {
        eint256 value = eint256.wrap(int256Handle);
        vm.expectCall(acl, abi.encodeCall(IACL.isAllowed, (int256Handle, account)));
        Nox.isAllowed(value, account);
    }

    // ============ allowPublicDecryption(<type>) ============

    function test_allowPublicDecryption_ebool() public {
        ebool value = ebool.wrap(boolHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (boolHandle)));
        Nox.allowPublicDecryption(value);
    }

    function test_allowPublicDecryption_eaddress() public {
        eaddress value = eaddress.wrap(addressHandle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (addressHandle)));
        Nox.allowPublicDecryption(value);
    }

    function test_allowPublicDecryption_euint256() public {
        euint256 value = euint256.wrap(uint256HandleA);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (uint256HandleA)));
        Nox.allowPublicDecryption(value);
    }

    function test_allowPublicDecryption_eint256() public {
        eint256 value = eint256.wrap(int256Handle);
        vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (int256Handle)));
        Nox.allowPublicDecryption(value);
    }

    /**
     * Helper function to allow this test contract as a caller of the given handle.
     */
    function _allowCaller(bytes32 handle) internal {
        vm.startPrank(noxCompute);
        aclContract.allowTransient(handle, address(this));
        vm.stopPrank();
        aclContract.allow(handle, address(this));
    }
}
