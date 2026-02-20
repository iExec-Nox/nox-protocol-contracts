// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "encrypted-types/EncryptedTypes.sol";
import {IACL} from "../../../contracts/interfaces/IACL.sol";
import {INoxCompute} from "../../../contracts/interfaces/INoxCompute.sol";
import {TEEType, TypeUtils} from "../../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";
import {Nox} from "../../../contracts/sdk/Nox.sol";
import {NoxFromExternalMock} from "../../../contracts/mock/NoxFromExternalMock.sol";

// Note: these tests are here to make sure the library calls the correct
// functions on the NoxCompute and ACL, and that the `isInitialized`
// function works as expected. The actual logic of most functions is tested
// in the NoxCompute and ACL tests, so we can keep these tests
// relatively light.

contract NoxTest is Test {
    using TypeUtils for bytes32;

    address owner = makeAddr("owner");
    address account = makeAddr("account");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    IACL aclContract;
    INoxCompute noxComputeContract;
    address acl;
    address noxCompute;

    // Individual handles
    bytes32 boolHandle = TestHelper.createHandle(TEEType.Bool);
    bytes32 addressHandle = TestHelper.createHandle(TEEType.Address);
    bytes32 int16HandleA = TestHelper.createHandle(TEEType.Int16);
    bytes32 int16HandleB = TestHelper.createHandle(TEEType.Int16);
    bytes32 int256HandleA = TestHelper.createHandle(TEEType.Int256);
    bytes32 int256HandleB = TestHelper.createHandle(TEEType.Int256);
    bytes32 uint16HandleA = TestHelper.createHandle(TEEType.Uint16);
    bytes32 uint16HandleB = TestHelper.createHandle(TEEType.Uint16);
    bytes32 uint256HandleA = TestHelper.createHandle(TEEType.Uint256);
    bytes32 uint256HandleB = TestHelper.createHandle(TEEType.Uint256);
    bytes32 uint256HandleC = TestHelper.createHandle(TEEType.Uint256);
    NoxFromExternalMock noxFromExternalMock;

    // Arithmetic type handle pairs (types that support add/sub/mul/div/safe/select)
    bytes32[] arithmeticA;
    bytes32[] arithmeticB;
    // TEEType for each arithmetic position: matches arithmeticA/B order
    TEEType[] arithmeticTypes;

    // All handles for ACL tests (one per type)
    bytes32[] allHandles;

    function setUp() public {
        (aclContract, noxComputeContract) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        noxCompute = address(noxComputeContract);

        noxFromExternalMock = new NoxFromExternalMock();
        // Allow all handles for the test contract
        _allowCaller(boolHandle);
        _allowCaller(addressHandle);
        _allowCaller(int16HandleA);
        _allowCaller(int16HandleB);
        _allowCaller(int256HandleA);
        _allowCaller(int256HandleB);
        _allowCaller(uint16HandleA);
        _allowCaller(uint16HandleB);
        _allowCaller(uint256HandleA);
        _allowCaller(uint256HandleB);
        _allowCaller(uint256HandleC);
        // Build arithmetic handle pairs: euint16, euint256, eint16, eint256
        arithmeticA.push(uint16HandleA);
        arithmeticA.push(uint256HandleA);
        arithmeticA.push(int16HandleA);
        arithmeticA.push(int256HandleA);
        arithmeticB.push(uint16HandleB);
        arithmeticB.push(uint256HandleB);
        arithmeticB.push(int16HandleB);
        arithmeticB.push(int256HandleB);
        // Build arithmetic type array: matches arithmeticA/B order
        arithmeticTypes.push(TEEType.Uint16);
        arithmeticTypes.push(TEEType.Uint256);
        arithmeticTypes.push(TEEType.Int16);
        arithmeticTypes.push(TEEType.Int256);

        // Build all handles: ebool, eaddress, euint16, euint256, eint16, eint256
        allHandles.push(boolHandle);
        allHandles.push(addressHandle);
        allHandles.push(uint16HandleA);
        allHandles.push(uint256HandleA);
        allHandles.push(int16HandleA);
        allHandles.push(int256HandleA);

        vm.label(account, "account");
        vm.label(address(noxFromExternalMock), "NoxFromExternalMock");
    }

    // ============ isInitialized ============

    function test_isInitialized_True() public view {
        assertTrue(Nox.isInitialized(ebool.wrap(boolHandle)));
        assertTrue(Nox.isInitialized(eaddress.wrap(addressHandle)));
        assertTrue(Nox.isInitialized(euint16.wrap(uint16HandleA)));
        assertTrue(Nox.isInitialized(euint256.wrap(uint256HandleA)));
        assertTrue(Nox.isInitialized(eint16.wrap(int16HandleA)));
        assertTrue(Nox.isInitialized(eint256.wrap(int256HandleA)));
    }

    function test_isInitialized_False() public pure {
        assertFalse(Nox.isInitialized(ebool.wrap(0)));
        assertFalse(Nox.isInitialized(eaddress.wrap(0)));
        assertFalse(Nox.isInitialized(euint16.wrap(0)));
        assertFalse(Nox.isInitialized(euint256.wrap(0)));
        assertFalse(Nox.isInitialized(eint16.wrap(0)));
        assertFalse(Nox.isInitialized(eint256.wrap(0)));
    }

    // ============ to<Type> ============

    function test_toEbool_True() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(uint256(1)), TEEType.Bool))
        );
        ebool result = Nox.toEbool(true);
        assertNotEq(ebool.unwrap(result), 0);
    }

    function test_toEbool_False() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(uint256(0)), TEEType.Bool))
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
                (bytes32(uint256(uint160(testAddress))), TEEType.Address)
            )
        );
        eaddress result = Nox.toEaddress(testAddress);
        assertNotEq(eaddress.unwrap(result), 0);
    }

    function test_toEuint16() public {
        uint16 value = 42;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(
                INoxCompute.plaintextToEncrypted,
                (bytes32(uint256(value)), TEEType.Uint16)
            )
        );
        euint16 result = Nox.toEuint16(value);
        assertNotEq(euint16.unwrap(result), 0);
    }

    function test_toEuint256() public {
        uint256 value = 12345;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(value), TEEType.Uint256))
        );
        euint256 result = Nox.toEuint256(value);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_toEint16() public {
        int16 value = -42;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(
                INoxCompute.plaintextToEncrypted,
                (bytes32(uint256(uint16(value))), TEEType.Int16)
            )
        );
        eint16 result = Nox.toEint16(value);
        assertNotEq(eint16.unwrap(result), 0);
    }

    function test_toEint256() public {
        int256 value = -12345;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(
                INoxCompute.plaintextToEncrypted,
                (bytes32(uint256(value)), TEEType.Int256)
            )
        );
        eint256 result = Nox.toEint256(value);
        assertNotEq(eint256.unwrap(result), 0);
    }

    // ============ fromExternal ============

    function test_fromExternal() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            address handleOwner = makeAddr("handleOwner");
            TEEType t = allHandles[i].typeOf();
            bytes memory proof = TestHelper.buildProof(
                noxCompute,
                allHandles[i],
                handleOwner,
                address(noxFromExternalMock),
                block.timestamp,
                gatewayPrivateKey
            );
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.validateProof, (allHandles[i], handleOwner, proof, t))
            );
            // Use startPrank/stopPrank instead of prank to avoid coverage instrumentation
            // consuming the single-use prank before the intended external call.
            vm.startPrank(handleOwner);
            _noxFromExternal(allHandles[i], proof);
            vm.stopPrank();
        }
    }

    // ============ Unsafe Arithmetic primitives ============

    function test_add() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.add, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxAdd(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_add_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxAddTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxAddTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_sub() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.sub, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxSub(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_sub_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSubTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSubTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_mul() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.mul, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxMul(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_mul_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxMulTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxMulTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_div() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.div, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxDiv(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_div_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxDivTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxDivTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    // ============ Safe arithmetic primitives ============

    function test_safeAdd() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.safeAdd, (arithmeticA[i], arithmeticB[i]))
            );
            (bytes32 success, bytes32 result) = _noxSafeAdd(arithmeticA[i], arithmeticB[i]);
            assertNotEq(success, 0);
            assertNotEq(result, 0);
        }
    }

    function test_safeAdd_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSafeAddTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSafeAddTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_safeSub() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.safeSub, (arithmeticA[i], arithmeticB[i]))
            );
            (bytes32 success, bytes32 result) = _noxSafeSub(arithmeticA[i], arithmeticB[i]);
            assertNotEq(success, 0);
            assertNotEq(result, 0);
        }
    }

    function test_safeSub_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSafeSubTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSafeSubTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    // ============ select ============

    function test_select() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.select, (boolHandle, arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxSelect(boolHandle, arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_select_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            // uninitialized condition
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Bool))
            );
            _noxSelectTyped(t, bytes32(0), arithmeticA[i], arithmeticB[i]);
            // uninitialized ifTrue
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSelectTyped(t, boolHandle, bytes32(0), arithmeticB[i]);
            // uninitialized ifFalse
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxSelectTyped(t, boolHandle, arithmeticA[i], bytes32(0));
        }
    }

    // ============ Comparison functions ============

    function test_Eq() public {
        // uint16
        _expectCall(INoxCompute.eq.selector, uint16HandleA, uint16HandleB);
        Nox.eq(euint16.wrap(uint16HandleA), euint16.wrap(uint16HandleB));
        // uint256
        _expectCall(INoxCompute.eq.selector, uint256HandleA, uint256HandleB);
        Nox.eq(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB));
        // int16
        _expectCall(INoxCompute.eq.selector, int16HandleA, int16HandleB);
        Nox.eq(eint16.wrap(int16HandleA), eint16.wrap(int16HandleB));
        // int256
        _expectCall(INoxCompute.eq.selector, int256HandleA, int256HandleB);
        Nox.eq(eint256.wrap(int256HandleA), eint256.wrap(int256HandleB));
    }

    function test_Eq_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxEqTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxEqTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_Ne() public {
        // uint16
        _expectCall(INoxCompute.ne.selector, uint16HandleA, uint16HandleB);
        Nox.ne(euint16.wrap(uint16HandleA), euint16.wrap(uint16HandleB));
        // uint256
        _expectCall(INoxCompute.ne.selector, uint256HandleA, uint256HandleB);
        Nox.ne(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB));
        // int16
        _expectCall(INoxCompute.ne.selector, int16HandleA, int16HandleB);
        Nox.ne(eint16.wrap(int16HandleA), eint16.wrap(int16HandleB));
        // int256
        _expectCall(INoxCompute.ne.selector, int256HandleA, int256HandleB);
        Nox.ne(eint256.wrap(int256HandleA), eint256.wrap(int256HandleB));
    }

    function test_Ne_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxNeTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxNeTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_Lt() public {
        // uint16
        _expectCall(INoxCompute.lt.selector, uint16HandleA, uint16HandleB);
        Nox.lt(euint16.wrap(uint16HandleA), euint16.wrap(uint16HandleB));
        // uint256
        _expectCall(INoxCompute.lt.selector, uint256HandleA, uint256HandleB);
        Nox.lt(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB));
        // int16
        _expectCall(INoxCompute.lt.selector, int16HandleA, int16HandleB);
        Nox.lt(eint16.wrap(int16HandleA), eint16.wrap(int16HandleB));
        // int256
        _expectCall(INoxCompute.lt.selector, int256HandleA, int256HandleB);
        Nox.lt(eint256.wrap(int256HandleA), eint256.wrap(int256HandleB));
    }

    function test_Lt_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxLtTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxLtTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_Le() public {
        // uint16
        _expectCall(INoxCompute.le.selector, uint16HandleA, uint16HandleB);
        Nox.le(euint16.wrap(uint16HandleA), euint16.wrap(uint16HandleB));
        // uint256
        _expectCall(INoxCompute.le.selector, uint256HandleA, uint256HandleB);
        Nox.le(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB));
        // int16
        _expectCall(INoxCompute.le.selector, int16HandleA, int16HandleB);
        Nox.le(eint16.wrap(int16HandleA), eint16.wrap(int16HandleB));
        // int256
        _expectCall(INoxCompute.le.selector, int256HandleA, int256HandleB);
        Nox.le(eint256.wrap(int256HandleA), eint256.wrap(int256HandleB));
    }

    function test_Le_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxLeTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxLeTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_Gt() public {
        // uint16
        _expectCall(INoxCompute.gt.selector, uint16HandleA, uint16HandleB);
        Nox.gt(euint16.wrap(uint16HandleA), euint16.wrap(uint16HandleB));
        // uint256
        _expectCall(INoxCompute.gt.selector, uint256HandleA, uint256HandleB);
        Nox.gt(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB));
        // int16
        _expectCall(INoxCompute.gt.selector, int16HandleA, int16HandleB);
        Nox.gt(eint16.wrap(int16HandleA), eint16.wrap(int16HandleB));
        // int256
        _expectCall(INoxCompute.gt.selector, int256HandleA, int256HandleB);
        Nox.gt(eint256.wrap(int256HandleA), eint256.wrap(int256HandleB));
    }

    function test_Gt_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxGtTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxGtTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    function test_Ge() public {
        // uint16
        _expectCall(INoxCompute.ge.selector, uint16HandleA, uint16HandleB);
        Nox.ge(euint16.wrap(uint16HandleA), euint16.wrap(uint16HandleB));
        // uint256
        _expectCall(INoxCompute.ge.selector, uint256HandleA, uint256HandleB);
        Nox.ge(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB));
        // int16
        _expectCall(INoxCompute.ge.selector, int16HandleA, int16HandleB);
        Nox.ge(eint16.wrap(int16HandleA), eint16.wrap(int16HandleB));
        // int256
        _expectCall(INoxCompute.ge.selector, int256HandleA, int256HandleB);
        Nox.ge(eint256.wrap(int256HandleA), eint256.wrap(int256HandleB));
    }

    function test_Ge_UninitializedHandles() public {
        for (uint256 i = 0; i < arithmeticTypes.length; i++) {
            TEEType t = arithmeticTypes[i];
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxGeTyped(t, bytes32(0), arithmeticB[i]);
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), t))
            );
            _noxGeTyped(t, arithmeticA[i], bytes32(0));
        }
    }

    // ============ Advanced functions ============

    function test_Transfer() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.transfer, (uint256HandleA, uint256HandleB, uint256HandleC))
        );
        Nox.transfer(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
    }

    function test_Transfer_UninitializedHandles() public {
        // uninitialized balanceFrom
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.transfer(
            euint256.wrap(0),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
        // uninitialized balanceTo
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.transfer(
            euint256.wrap(uint256HandleA),
            euint256.wrap(0),
            euint256.wrap(uint256HandleC)
        );
        // uninitialized amount
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.transfer(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(0)
        );
    }

    function test_Mint() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.mint, (uint256HandleA, uint256HandleB, uint256HandleC))
        );
        Nox.mint(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
    }

    function test_Mint_UninitializedHandles() public {
        // uninitialized balanceTo
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.mint(euint256.wrap(0), euint256.wrap(uint256HandleB), euint256.wrap(uint256HandleC));
        // uninitialized amount
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.mint(euint256.wrap(uint256HandleA), euint256.wrap(0), euint256.wrap(uint256HandleC));
        // uninitialized totalSupply
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.mint(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB), euint256.wrap(0));
    }

    function test_Burn() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.burn, (uint256HandleA, uint256HandleB, uint256HandleC))
        );
        Nox.burn(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
    }

    function test_Burn_UninitializedHandles() public {
        // uninitialized balanceFrom
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.burn(euint256.wrap(0), euint256.wrap(uint256HandleB), euint256.wrap(uint256HandleC));
        // uninitialized amount
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.burn(euint256.wrap(uint256HandleA), euint256.wrap(0), euint256.wrap(uint256HandleC));
        // uninitialized totalSupply
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.plaintextToEncrypted, (bytes32(0), TEEType.Uint256))
        );
        Nox.burn(euint256.wrap(uint256HandleA), euint256.wrap(uint256HandleB), euint256.wrap(0));
    }

    // ============ allow ============

    function test_allow() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.allow, (allHandles[i], account)));
            _noxAllow(allHandles[i], account);
        }
    }

    // ============ allowThis ============

    function test_allowThis() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.allow, (allHandles[i], address(this))));
            _noxAllowThis(allHandles[i]);
        }
    }

    // ============ allowTransient ============

    function test_allowTransient() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.allowTransient, (allHandles[i], account)));
            _noxAllowTransient(allHandles[i], account);
        }
    }

    // ============ isAllowed ============

    function test_isAllowed() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.isAllowed, (allHandles[i], account)));
            _noxIsAllowed(allHandles[i], account);
        }
    }

    // ============ addViewer ============

    function test_addViewer() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.addViewer, (allHandles[i], account)));
            _noxAddViewer(allHandles[i], account);
        }
    }

    // ============ isViewer ============

    function test_isViewer() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.isViewer, (allHandles[i], account)));
            _noxIsViewer(allHandles[i], account);
        }
    }

    // ============ allowPublicDecryption ============

    function test_allowPublicDecryption() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.allowPublicDecryption, (allHandles[i])));
            _noxAllowPublicDecryption(allHandles[i]);
        }
    }

    // ============ isPubliclyDecryptable ============

    function test_isPubliclyDecryptable() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(acl, abi.encodeCall(IACL.isPubliclyDecryptable, (allHandles[i])));
            _noxIsPubliclyDecryptable(allHandles[i]);
        }
    }

    // ============ Typed Dispatch Helpers (for uninitialized handle tests) ============

    function _noxAddTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return euint16.unwrap(Nox.add(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return euint256.unwrap(Nox.add(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return eint16.unwrap(Nox.add(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256)
            return eint256.unwrap(Nox.add(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxSubTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return euint16.unwrap(Nox.sub(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return euint256.unwrap(Nox.sub(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return eint16.unwrap(Nox.sub(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256)
            return eint256.unwrap(Nox.sub(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxMulTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return euint16.unwrap(Nox.mul(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return euint256.unwrap(Nox.mul(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return eint16.unwrap(Nox.mul(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256)
            return eint256.unwrap(Nox.mul(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxDivTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return euint16.unwrap(Nox.div(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return euint256.unwrap(Nox.div(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return eint16.unwrap(Nox.div(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256)
            return eint256.unwrap(Nox.div(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxSafeAddTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeAdd(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        } else if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeAdd(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        } else if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeAdd(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        } else if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeAdd(eint256.wrap(a), eint256.wrap(b));
            return (ebool.unwrap(s), eint256.unwrap(r));
        }
        revert("unsupported type");
    }

    function _noxSafeSubTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeSub(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        } else if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeSub(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        } else if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeSub(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        } else if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeSub(eint256.wrap(a), eint256.wrap(b));
            return (ebool.unwrap(s), eint256.unwrap(r));
        }
        revert("unsupported type");
    }

    function _noxSelectTyped(
        TEEType t,
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) internal returns (bytes32) {
        if (t == TEEType.Uint16) {
            return
                euint16.unwrap(
                    Nox.select(ebool.wrap(condition), euint16.wrap(ifTrue), euint16.wrap(ifFalse))
                );
        } else if (t == TEEType.Uint256) {
            return
                euint256.unwrap(
                    Nox.select(ebool.wrap(condition), euint256.wrap(ifTrue), euint256.wrap(ifFalse))
                );
        } else if (t == TEEType.Int16) {
            return
                eint16.unwrap(
                    Nox.select(ebool.wrap(condition), eint16.wrap(ifTrue), eint16.wrap(ifFalse))
                );
        } else if (t == TEEType.Int256) {
            return
                eint256.unwrap(
                    Nox.select(ebool.wrap(condition), eint256.wrap(ifTrue), eint256.wrap(ifFalse))
                );
        }
        revert("unsupported type");
    }

    function _noxEqTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.eq(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.eq(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.eq(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.eq(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxNeTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.ne(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.ne(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.ne(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.ne(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxLtTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.lt(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.lt(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.lt(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.lt(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxLeTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.le(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.le(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.le(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.le(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxGtTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.gt(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.gt(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.gt(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.gt(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxGeTyped(TEEType t, bytes32 a, bytes32 b) internal returns (bytes32) {
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.ge(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.ge(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.ge(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.ge(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    // ============ Dispatch Helpers ============

    function _noxFromExternal(bytes32 handle, bytes memory proof) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            noxFromExternalMock.fromExternalEbool(externalEbool.wrap(handle), proof);
        } else if (t == TEEType.Address) {
            noxFromExternalMock.fromExternalEaddress(externalEaddress.wrap(handle), proof);
        } else if (t == TEEType.Uint16) {
            noxFromExternalMock.fromExternalEuint16(externalEuint16.wrap(handle), proof);
        } else if (t == TEEType.Uint256) {
            noxFromExternalMock.fromExternalEuint256(externalEuint256.wrap(handle), proof);
        } else if (t == TEEType.Int16) {
            noxFromExternalMock.fromExternalEint16(externalEint16.wrap(handle), proof);
        } else if (t == TEEType.Int256) {
            noxFromExternalMock.fromExternalEint256(externalEint256.wrap(handle), proof);
        } else {
            revert("unsupported type");
        }
    }

    function _noxAdd(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.add(euint16.wrap(a), euint16.wrap(b)));
        } else if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.add(euint256.wrap(a), euint256.wrap(b)));
        } else if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.add(eint16.wrap(a), eint16.wrap(b)));
        } else if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.add(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxSub(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.sub(euint16.wrap(a), euint16.wrap(b)));
        } else if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.sub(euint256.wrap(a), euint256.wrap(b)));
        } else if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.sub(eint16.wrap(a), eint16.wrap(b)));
        } else if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.sub(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxMul(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.mul(euint16.wrap(a), euint16.wrap(b)));
        } else if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.mul(euint256.wrap(a), euint256.wrap(b)));
        } else if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.mul(eint16.wrap(a), eint16.wrap(b)));
        } else if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.mul(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxDiv(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.div(euint16.wrap(a), euint16.wrap(b)));
        } else if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.div(euint256.wrap(a), euint256.wrap(b)));
        } else if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.div(eint16.wrap(a), eint16.wrap(b)));
        } else if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.div(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxSafeAdd(bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeAdd(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        } else if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeAdd(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        } else if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeAdd(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        } else if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeAdd(eint256.wrap(a), eint256.wrap(b));
            return (ebool.unwrap(s), eint256.unwrap(r));
        }
        revert("unsupported type");
    }

    function _noxSafeSub(bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeSub(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        } else if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeSub(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        } else if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeSub(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        } else if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeSub(eint256.wrap(a), eint256.wrap(b));
            return (ebool.unwrap(s), eint256.unwrap(r));
        }
        revert("unsupported type");
    }

    function _noxSelect(
        bytes32 condition,
        bytes32 ifTrue,
        bytes32 ifFalse
    ) internal returns (bytes32) {
        TEEType t = ifTrue.typeOf();
        if (t == TEEType.Uint16) {
            return
                euint16.unwrap(
                    Nox.select(ebool.wrap(condition), euint16.wrap(ifTrue), euint16.wrap(ifFalse))
                );
        } else if (t == TEEType.Uint256) {
            return
                euint256.unwrap(
                    Nox.select(ebool.wrap(condition), euint256.wrap(ifTrue), euint256.wrap(ifFalse))
                );
        } else if (t == TEEType.Int16) {
            return
                eint16.unwrap(
                    Nox.select(ebool.wrap(condition), eint16.wrap(ifTrue), eint16.wrap(ifFalse))
                );
        } else if (t == TEEType.Int256) {
            return
                eint256.unwrap(
                    Nox.select(ebool.wrap(condition), eint256.wrap(ifTrue), eint256.wrap(ifFalse))
                );
        }
        revert("unsupported type");
    }

    function _noxAllow(bytes32 handle, address acc) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.allow(ebool.wrap(handle), acc);
        else if (t == TEEType.Address) Nox.allow(eaddress.wrap(handle), acc);
        else if (t == TEEType.Uint16) Nox.allow(euint16.wrap(handle), acc);
        else if (t == TEEType.Uint256) Nox.allow(euint256.wrap(handle), acc);
        else if (t == TEEType.Int16) Nox.allow(eint16.wrap(handle), acc);
        else if (t == TEEType.Int256) Nox.allow(eint256.wrap(handle), acc);
        else revert("unsupported type");
    }

    function _noxAllowThis(bytes32 handle) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.allowThis(ebool.wrap(handle));
        else if (t == TEEType.Address) Nox.allowThis(eaddress.wrap(handle));
        else if (t == TEEType.Uint16) Nox.allowThis(euint16.wrap(handle));
        else if (t == TEEType.Uint256) Nox.allowThis(euint256.wrap(handle));
        else if (t == TEEType.Int16) Nox.allowThis(eint16.wrap(handle));
        else if (t == TEEType.Int256) Nox.allowThis(eint256.wrap(handle));
        else revert("unsupported type");
    }

    function _noxAllowTransient(bytes32 handle, address acc) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.allowTransient(ebool.wrap(handle), acc);
        else if (t == TEEType.Address) Nox.allowTransient(eaddress.wrap(handle), acc);
        else if (t == TEEType.Uint16) Nox.allowTransient(euint16.wrap(handle), acc);
        else if (t == TEEType.Uint256) Nox.allowTransient(euint256.wrap(handle), acc);
        else if (t == TEEType.Int16) Nox.allowTransient(eint16.wrap(handle), acc);
        else if (t == TEEType.Int256) Nox.allowTransient(eint256.wrap(handle), acc);
        else revert("unsupported type");
    }

    function _noxIsAllowed(bytes32 handle, address acc) internal view {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.isAllowed(ebool.wrap(handle), acc);
        else if (t == TEEType.Address) Nox.isAllowed(eaddress.wrap(handle), acc);
        else if (t == TEEType.Uint16) Nox.isAllowed(euint16.wrap(handle), acc);
        else if (t == TEEType.Uint256) Nox.isAllowed(euint256.wrap(handle), acc);
        else if (t == TEEType.Int16) Nox.isAllowed(eint16.wrap(handle), acc);
        else if (t == TEEType.Int256) Nox.isAllowed(eint256.wrap(handle), acc);
        else revert("unsupported type");
    }

    function _noxAddViewer(bytes32 handle, address viewer) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.addViewer(ebool.wrap(handle), viewer);
        else if (t == TEEType.Address) Nox.addViewer(eaddress.wrap(handle), viewer);
        else if (t == TEEType.Uint16) Nox.addViewer(euint16.wrap(handle), viewer);
        else if (t == TEEType.Uint256) Nox.addViewer(euint256.wrap(handle), viewer);
        else if (t == TEEType.Int16) Nox.addViewer(eint16.wrap(handle), viewer);
        else if (t == TEEType.Int256) Nox.addViewer(eint256.wrap(handle), viewer);
        else revert("unsupported type");
    }

    function _noxIsViewer(bytes32 handle, address viewer) internal view {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.isViewer(ebool.wrap(handle), viewer);
        else if (t == TEEType.Address) Nox.isViewer(eaddress.wrap(handle), viewer);
        else if (t == TEEType.Uint16) Nox.isViewer(euint16.wrap(handle), viewer);
        else if (t == TEEType.Uint256) Nox.isViewer(euint256.wrap(handle), viewer);
        else if (t == TEEType.Int16) Nox.isViewer(eint16.wrap(handle), viewer);
        else if (t == TEEType.Int256) Nox.isViewer(eint256.wrap(handle), viewer);
        else revert("unsupported type");
    }

    function _noxAllowPublicDecryption(bytes32 handle) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.allowPublicDecryption(ebool.wrap(handle));
        else if (t == TEEType.Address) Nox.allowPublicDecryption(eaddress.wrap(handle));
        else if (t == TEEType.Uint16) Nox.allowPublicDecryption(euint16.wrap(handle));
        else if (t == TEEType.Uint256) Nox.allowPublicDecryption(euint256.wrap(handle));
        else if (t == TEEType.Int16) Nox.allowPublicDecryption(eint16.wrap(handle));
        else if (t == TEEType.Int256) Nox.allowPublicDecryption(eint256.wrap(handle));
        else revert("unsupported type");
    }

    function _noxIsPubliclyDecryptable(bytes32 handle) internal view {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) Nox.isPubliclyDecryptable(ebool.wrap(handle));
        else if (t == TEEType.Address) Nox.isPubliclyDecryptable(eaddress.wrap(handle));
        else if (t == TEEType.Uint16) Nox.isPubliclyDecryptable(euint16.wrap(handle));
        else if (t == TEEType.Uint256) Nox.isPubliclyDecryptable(euint256.wrap(handle));
        else if (t == TEEType.Int16) Nox.isPubliclyDecryptable(eint16.wrap(handle));
        else if (t == TEEType.Int256) Nox.isPubliclyDecryptable(eint256.wrap(handle));
        else revert("unsupported type");
    }

    // ============ Internal Helpers ============

    /**
     * Helper function to allow this test contract as a caller of the given handle.
     */
    function _allowCaller(bytes32 handle) internal {
        vm.startPrank(noxCompute);
        aclContract.allowTransient(handle, address(this));
        vm.stopPrank();
        aclContract.allow(handle, address(this));
    }

    function _expectCall(bytes4 selector, bytes32 arg1, bytes32 arg2) internal {
        vm.expectCall(noxCompute, abi.encodeWithSelector(selector, arg1, arg2));
    }
}
