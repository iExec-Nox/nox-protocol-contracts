// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "encrypted-types/EncryptedTypes.sol";
import {IACL} from "../../../contracts/interfaces/IACL.sol";
import {INoxCompute} from "../../../contracts/interfaces/INoxCompute.sol";
import {TEEType, TypeUtils} from "../../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";
import {Nox} from "../../../contracts/sdk/Nox.sol";
import {NoxMock} from "../../../contracts/mock/NoxMock.sol";

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
    NoxMock noxMock;

    // Arithmetic type handle pairs (types that support add/sub/mul/div/safe/select)
    bytes32[] arithmeticA;
    bytes32[] arithmeticB;

    // All handles for ACL tests (one per type)
    bytes32[] allHandles;

    function setUp() public {
        (aclContract, noxComputeContract) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        noxCompute = address(noxComputeContract);

        noxMock = new NoxMock();
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
        // Build all handles: ebool, eaddress, euint16, euint256, eint16, eint256
        allHandles.push(boolHandle);
        allHandles.push(addressHandle);
        allHandles.push(uint16HandleA);
        allHandles.push(uint256HandleA);
        allHandles.push(int16HandleA);
        allHandles.push(int256HandleA);

        vm.label(account, "account");
        vm.label(address(noxMock), "NoxMock");
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
                address(noxMock),
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

    function test_RevertWhen_add_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.addEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_sub_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.subEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_mul_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mulEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_div_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.divEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_safeAdd_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeAddEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_safeSub_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.safeSubEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_select_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEuint16(bytes32(0), uint16HandleA, uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEuint16(boolHandle, bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEuint16(boolHandle, uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEuint256(bytes32(0), uint256HandleA, uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEuint256(boolHandle, bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEuint256(boolHandle, uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEint16(bytes32(0), int16HandleA, int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEint16(boolHandle, bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEint16(boolHandle, int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEint256(bytes32(0), int256HandleA, int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEint256(boolHandle, bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.selectEint256(boolHandle, int256HandleA, bytes32(0));
    }

    // ============ Comparison functions ============

    function test_Eq() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            _expectCall(INoxCompute.eq.selector, arithmeticA[i], arithmeticB[i]);
            bytes32 result = _noxEq(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_RevertWhen_Eq_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.eqEint256(int256HandleA, bytes32(0));
    }

    function test_Ne() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            _expectCall(INoxCompute.ne.selector, arithmeticA[i], arithmeticB[i]);
            bytes32 result = _noxNe(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_RevertWhen_Ne_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.neEint256(int256HandleA, bytes32(0));
    }

    function test_Lt() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            _expectCall(INoxCompute.lt.selector, arithmeticA[i], arithmeticB[i]);
            bytes32 result = _noxLt(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_RevertWhen_Lt_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.ltEint256(int256HandleA, bytes32(0));
    }

    function test_Le() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            _expectCall(INoxCompute.le.selector, arithmeticA[i], arithmeticB[i]);
            bytes32 result = _noxLe(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_RevertWhen_Le_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.leEint256(int256HandleA, bytes32(0));
    }

    function test_Gt() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            _expectCall(INoxCompute.gt.selector, arithmeticA[i], arithmeticB[i]);
            bytes32 result = _noxGt(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_RevertWhen_Gt_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.gtEint256(int256HandleA, bytes32(0));
    }

    function test_Ge() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            _expectCall(INoxCompute.ge.selector, arithmeticA[i], arithmeticB[i]);
            bytes32 result = _noxGe(arithmeticA[i], arithmeticB[i]);
            assertNotEq(result, 0);
        }
    }

    function test_RevertWhen_Ge_UninitializedHandle() public {
        // uint16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEuint16(bytes32(0), uint16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEuint16(uint16HandleA, bytes32(0));
        // uint256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEuint256(bytes32(0), uint256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEuint256(uint256HandleA, bytes32(0));
        // int16
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEint16(bytes32(0), int16HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEint16(int16HandleA, bytes32(0));
        // int256
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEint256(bytes32(0), int256HandleB);
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.geEint256(int256HandleA, bytes32(0));
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

    function test_RevertWhen_Transfer_UninitializedHandle() public {
        // uninitialized balanceFrom
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.transfer(bytes32(0), uint256HandleB, uint256HandleC);
        // uninitialized balanceTo
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.transfer(uint256HandleA, bytes32(0), uint256HandleC);
        // uninitialized amount
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.transfer(uint256HandleA, uint256HandleB, bytes32(0));
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

    function test_RevertWhen_Mint_UninitializedHandle() public {
        // uninitialized balanceTo
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mint(bytes32(0), uint256HandleB, uint256HandleC);
        // uninitialized amount
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mint(uint256HandleA, bytes32(0), uint256HandleC);
        // uninitialized totalSupply
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.mint(uint256HandleA, uint256HandleB, bytes32(0));
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

    function test_RevertWhen_Burn_UninitializedHandle() public {
        // uninitialized balanceFrom
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.burn(bytes32(0), uint256HandleB, uint256HandleC);
        // uninitialized amount
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.burn(uint256HandleA, bytes32(0), uint256HandleC);
        // uninitialized totalSupply
        vm.expectRevert(Nox.UninitializedHandle.selector);
        noxMock.burn(uint256HandleA, uint256HandleB, bytes32(0));
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

    // ============ Dispatch Helpers ============

    function _noxFromExternal(bytes32 handle, bytes memory proof) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            noxMock.fromExternalEbool(externalEbool.wrap(handle), proof);
        } else if (t == TEEType.Address) {
            noxMock.fromExternalEaddress(externalEaddress.wrap(handle), proof);
        } else if (t == TEEType.Uint16) {
            noxMock.fromExternalEuint16(externalEuint16.wrap(handle), proof);
        } else if (t == TEEType.Uint256) {
            noxMock.fromExternalEuint256(externalEuint256.wrap(handle), proof);
        } else if (t == TEEType.Int16) {
            noxMock.fromExternalEint16(externalEint16.wrap(handle), proof);
        } else if (t == TEEType.Int256) {
            noxMock.fromExternalEint256(externalEint256.wrap(handle), proof);
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

    function _noxEq(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.eq(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.eq(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.eq(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.eq(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxNe(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.ne(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.ne(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.ne(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.ne(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxLt(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.lt(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.lt(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.lt(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.lt(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxLe(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.le(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.le(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.le(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.le(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxGt(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.gt(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.gt(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.gt(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.gt(eint256.wrap(a), eint256.wrap(b)));
        revert("unsupported type");
    }

    function _noxGe(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) return ebool.unwrap(Nox.ge(euint16.wrap(a), euint16.wrap(b)));
        else if (t == TEEType.Uint256)
            return ebool.unwrap(Nox.ge(euint256.wrap(a), euint256.wrap(b)));
        else if (t == TEEType.Int16) return ebool.unwrap(Nox.ge(eint16.wrap(a), eint16.wrap(b)));
        else if (t == TEEType.Int256) return ebool.unwrap(Nox.ge(eint256.wrap(a), eint256.wrap(b)));
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
