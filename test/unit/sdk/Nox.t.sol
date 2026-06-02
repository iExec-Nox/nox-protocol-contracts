// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import "encrypted-types/EncryptedTypes.sol";
import {INoxCompute} from "../../../contracts/interfaces/INoxCompute.sol";
import {TEEType, TypeUtils} from "../../../contracts/utils/TypeUtils.sol";
import {TestHelper} from "../../utils/TestHelper.sol";
import {Nox} from "../../../contracts/sdk/Nox.sol";
import {NoxMock} from "../../../contracts/mock/NoxMock.sol";

// Note: these tests are here to make sure the library calls the correct
// functions on the NoxCompute, and that the `isInitialized`
// function works as expected. The actual logic of most functions is tested
// in the NoxCompute tests, so we can keep these tests
// relatively light.

contract NoxTest is Test {
    using TypeUtils for bytes32;

    address owner = makeAddr("owner");
    address account = makeAddr("account");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    INoxCompute noxComputeContract;
    address noxCompute;

    // Individual handles
    bytes32 boolHandle = TestHelper.createHandle(TEEType.Bool);
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
        noxComputeContract = TestHelper.deploy(owner, owner, gateway);
        noxCompute = address(noxComputeContract);

        noxMock = new NoxMock();
        // Allow all handles for the test contract
        TestHelper.forceAllowPersistent(boolHandle, address(this));
        TestHelper.forceAllowPersistent(int16HandleA, address(this));
        TestHelper.forceAllowPersistent(int16HandleB, address(this));
        TestHelper.forceAllowPersistent(int256HandleA, address(this));
        TestHelper.forceAllowPersistent(int256HandleB, address(this));
        TestHelper.forceAllowPersistent(uint16HandleA, address(this));
        TestHelper.forceAllowPersistent(uint16HandleB, address(this));
        TestHelper.forceAllowPersistent(uint256HandleA, address(this));
        TestHelper.forceAllowPersistent(uint256HandleB, address(this));
        TestHelper.forceAllowPersistent(uint256HandleC, address(this));
        // Build arithmetic handle pairs: euint16, euint256, eint16, eint256
        arithmeticA.push(uint16HandleA);
        arithmeticA.push(uint256HandleA);
        arithmeticA.push(int16HandleA);
        arithmeticA.push(int256HandleA);
        arithmeticB.push(uint16HandleB);
        arithmeticB.push(uint256HandleB);
        arithmeticB.push(int16HandleB);
        arithmeticB.push(int256HandleB);
        // Build all handles: ebool, euint16, euint256, eint16, eint256
        allHandles.push(boolHandle);
        allHandles.push(uint16HandleA);
        allHandles.push(uint256HandleA);
        allHandles.push(int16HandleA);
        allHandles.push(int256HandleA);

        vm.label(account, "account");
        vm.label(address(noxMock), "NoxMock");
    }

    // ============ noxComputeContract ============

    function test_ContractAddress_ArbitrumSepolia() public {
        vm.chainId(421614);
        address arbitrumSepoliaCompute = noxMock.noxComputeContract();
        vm.mockCall(
            arbitrumSepoliaCompute,
            abi.encodeCall(INoxCompute.isAllowed, (boolHandle, account)),
            abi.encode(false)
        );
        vm.expectCall(
            arbitrumSepoliaCompute,
            abi.encodeCall(INoxCompute.isAllowed, (boolHandle, account))
        );
        Nox.isAllowed(ebool.wrap(boolHandle), account);
    }

    function test_ContractAddress_EthereumSepolia() public {
        vm.chainId(11155111);
        address ethereumSepoliaCompute = noxMock.noxComputeContract();
        vm.mockCall(
            ethereumSepoliaCompute,
            abi.encodeCall(INoxCompute.isAllowed, (boolHandle, account)),
            abi.encode(false)
        );
        vm.expectCall(
            ethereumSepoliaCompute,
            abi.encodeCall(INoxCompute.isAllowed, (boolHandle, account))
        );
        Nox.isAllowed(ebool.wrap(boolHandle), account);
    }

    function test_RevertWhen_ContractAddress_UnsupportedChain() public {
        vm.chainId(9999);
        vm.expectRevert("Nox: Unsupported chain");
        noxMock.addEuint16(uint16HandleA, uint16HandleB);
    }

    // ============ isInitialized ============

    function test_isInitialized_True() public view {
        assertTrue(Nox.isInitialized(ebool.wrap(boolHandle)));
        assertTrue(Nox.isInitialized(euint16.wrap(uint16HandleA)));
        assertTrue(Nox.isInitialized(euint256.wrap(uint256HandleA)));
        assertTrue(Nox.isInitialized(eint16.wrap(int16HandleA)));
        assertTrue(Nox.isInitialized(eint256.wrap(int256HandleA)));
    }

    function test_isInitialized_False() public pure {
        assertFalse(Nox.isInitialized(ebool.wrap(0)));
        assertFalse(Nox.isInitialized(euint16.wrap(0)));
        assertFalse(Nox.isInitialized(euint256.wrap(0)));
        assertFalse(Nox.isInitialized(eint16.wrap(0)));
        assertFalse(Nox.isInitialized(eint256.wrap(0)));
    }

    // ============ to<Type> ============

    function test_toEbool_True() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.wrapAsPublicHandle, (bytes32(uint256(1)), TEEType.Bool))
        );
        ebool result = Nox.toEbool(true);
        assertNotEq(ebool.unwrap(result), 0);
    }

    function test_toEbool_False() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.wrapAsPublicHandle, (bytes32(uint256(0)), TEEType.Bool))
        );
        ebool result = Nox.toEbool(false);
        assertNotEq(ebool.unwrap(result), 0);
    }

    function test_toEuint16() public {
        uint16 value = 42;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(
                INoxCompute.wrapAsPublicHandle,
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
            abi.encodeCall(INoxCompute.wrapAsPublicHandle, (bytes32(value), TEEType.Uint256))
        );
        euint256 result = Nox.toEuint256(value);
        assertNotEq(euint256.unwrap(result), 0);
    }

    function test_toEint16() public {
        int16 value = -42;
        vm.expectCall(
            noxCompute,
            abi.encodeCall(
                INoxCompute.wrapAsPublicHandle,
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
                INoxCompute.wrapAsPublicHandle,
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
            bytes memory proof = TestHelper.buildInputProof(
                noxCompute,
                allHandles[i],
                handleOwner,
                address(noxMock),
                block.timestamp,
                gatewayPrivateKey
            );
            vm.expectCall(
                noxCompute,
                abi.encodeCall(
                    INoxCompute.validateInputProof,
                    (allHandles[i], handleOwner, proof, t)
                )
            );
            // Use startPrank/stopPrank instead of prank to avoid coverage instrumentation
            // consuming the single-use prank before the intended external call.
            vm.startPrank(handleOwner);
            bytes32 handle = _noxFromExternal(allHandles[i], proof);
            vm.stopPrank();
            _assertHandleType(handle, t);
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
            _assertHandleType(result, arithmeticA[i].typeOf());
        }
    }

    function test_sub() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.sub, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxSub(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
        }
    }

    function test_mul() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.mul, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxMul(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
        }
    }

    function test_div() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.div, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxDiv(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
        }
    }

    function test_safeAdd() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.safeAdd, (arithmeticA[i], arithmeticB[i]))
            );
            (bytes32 success, bytes32 result) = _noxSafeAdd(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
            _assertHandleType(success, TEEType.Bool);
        }
    }

    function test_safeSub() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.safeSub, (arithmeticA[i], arithmeticB[i]))
            );
            (bytes32 success, bytes32 result) = _noxSafeSub(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
            _assertHandleType(success, TEEType.Bool);
        }
    }

    function test_safeMul() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.safeMul, (arithmeticA[i], arithmeticB[i]))
            );
            (bytes32 success, bytes32 result) = _noxSafeMul(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
            _assertHandleType(success, TEEType.Bool);
        }
    }

    function test_safeDiv() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.safeDiv, (arithmeticA[i], arithmeticB[i]))
            );
            (bytes32 success, bytes32 result) = _noxSafeDiv(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
            _assertHandleType(success, TEEType.Bool);
        }
    }

    function test_select() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.select, (boolHandle, arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxSelect(boolHandle, arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, arithmeticA[i].typeOf());
        }
    }

    function test_eq() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.eq, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxEq(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, TEEType.Bool);
        }
    }

    function test_ne() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.ne, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxNe(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, TEEType.Bool);
        }
    }

    function test_lt() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.lt, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxLt(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, TEEType.Bool);
        }
    }

    function test_le() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.le, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxLe(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, TEEType.Bool);
        }
    }

    function test_gt() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.gt, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxGt(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, TEEType.Bool);
        }
    }

    function test_ge() public {
        for (uint256 i = 0; i < arithmeticA.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.ge, (arithmeticA[i], arithmeticB[i]))
            );
            bytes32 result = _noxGe(arithmeticA[i], arithmeticB[i]);
            _assertHandleType(result, TEEType.Bool);
        }
    }

    function test_Transfer() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.transfer, (uint256HandleA, uint256HandleB, uint256HandleC))
        );
        (ebool success, euint256 newBalanceFrom, euint256 newBalanceTo) = Nox.transfer(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
        _assertHandleType(ebool.unwrap(success), TEEType.Bool);
        _assertHandleType(euint256.unwrap(newBalanceFrom), TEEType.Uint256);
        _assertHandleType(euint256.unwrap(newBalanceTo), TEEType.Uint256);
    }

    function test_Mint() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.mint, (uint256HandleA, uint256HandleB, uint256HandleC))
        );
        (ebool success, euint256 newBalanceTo, euint256 newTotalSupply) = Nox.mint(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
        _assertHandleType(ebool.unwrap(success), TEEType.Bool);
        _assertHandleType(euint256.unwrap(newBalanceTo), TEEType.Uint256);
        _assertHandleType(euint256.unwrap(newTotalSupply), TEEType.Uint256);
    }

    function test_Burn() public {
        vm.expectCall(
            noxCompute,
            abi.encodeCall(INoxCompute.burn, (uint256HandleA, uint256HandleB, uint256HandleC))
        );
        (ebool success, euint256 newBalanceFrom, euint256 newTotalSupply) = Nox.burn(
            euint256.wrap(uint256HandleA),
            euint256.wrap(uint256HandleB),
            euint256.wrap(uint256HandleC)
        );
        _assertHandleType(ebool.unwrap(success), TEEType.Bool);
        _assertHandleType(euint256.unwrap(newBalanceFrom), TEEType.Uint256);
        _assertHandleType(euint256.unwrap(newTotalSupply), TEEType.Uint256);
    }

    // TODO: Add null handle resolution tests (verify SDK resolves bytes32(0) to typed null handles)

    // ============ ACL functions ============

    function test_allow() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(noxCompute, abi.encodeCall(INoxCompute.allow, (allHandles[i], account)));
            _noxAllow(allHandles[i], account);
        }
    }

    function test_allowThis() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.allow, (allHandles[i], address(this)))
            );
            _noxAllowThis(allHandles[i]);
        }
    }

    function test_allowTransient() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.allowTransient, (allHandles[i], account))
            );
            _noxAllowTransient(allHandles[i], account);
        }
    }

    function test_disallowTransient() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.disallowTransient, (allHandles[i], account))
            );
            _noxDisallowTransient(allHandles[i], account);
        }
    }

    function test_isAllowed() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.isAllowed, (allHandles[i], account))
            );
            _noxIsAllowed(allHandles[i], account);
        }
    }

    function test_addViewer() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.addViewer, (allHandles[i], account))
            );
            _noxAddViewer(allHandles[i], account);
        }
    }

    function test_isViewer() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.isViewer, (allHandles[i], account))
            );
            _noxIsViewer(allHandles[i], account);
        }
    }

    function test_allowPublicDecryption() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.allowPublicDecryption, (allHandles[i]))
            );
            _noxAllowPublicDecryption(allHandles[i]);
        }
    }

    function test_isPubliclyDecryptable() public {
        for (uint256 i = 0; i < allHandles.length; i++) {
            vm.expectCall(
                noxCompute,
                abi.encodeCall(INoxCompute.isPubliclyDecryptable, (allHandles[i]))
            );
            _noxIsPubliclyDecryptable(allHandles[i]);
        }
    }

    // ============ publicDecrypt ============

    function test_publicDecrypt_Ebool() public {
        _makePubliclyDecryptable(boolHandle);
        bytes memory data = abi.encodePacked(uint8(1));
        bytes memory proof = TestHelper.buildDecryptionProof(boolHandle, data, gatewayPrivateKey);
        bool result = noxMock.publicDecryptEbool(boolHandle, proof);
        assertTrue(result);
    }

    function test_RevertWhen_PublicDecrypt_Ebool_DataSizeTooLarge() public {
        _makePubliclyDecryptable(boolHandle);
        bytes memory data = abi.encodePacked(uint16(1)); // > 1 byte
        bytes memory proof = TestHelper.buildDecryptionProof(boolHandle, data, gatewayPrivateKey);
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEbool(boolHandle, proof);
    }

    function test_publicDecrypt_Euint16() public {
        _makePubliclyDecryptable(uint16HandleA);
        bytes memory data = abi.encodePacked(uint16(42));
        bytes memory proof = TestHelper.buildDecryptionProof(
            uint16HandleA,
            data,
            gatewayPrivateKey
        );
        uint16 result = noxMock.publicDecryptEuint16(uint16HandleA, proof);
        assertEq(result, 42);
    }

    function test_RevertWhen_PublicDecrypt_Euint16_DataSizeTooSmall() public {
        _makePubliclyDecryptable(uint16HandleA);
        bytes memory data = abi.encodePacked(uint8(42)); // < 2 bytes
        bytes memory proof = TestHelper.buildDecryptionProof(
            uint16HandleA,
            data,
            gatewayPrivateKey
        );
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEuint16(uint16HandleA, proof);
    }

    function test_RevertWhen_PublicDecrypt_Euint16_DataSizeTooLarge() public {
        _makePubliclyDecryptable(uint16HandleA);
        bytes memory data = abi.encodePacked(uint24(42)); // > 2 bytes
        bytes memory proof = TestHelper.buildDecryptionProof(
            uint16HandleA,
            data,
            gatewayPrivateKey
        );
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEuint16(uint16HandleA, proof);
    }

    function test_publicDecrypt_Euint256() public {
        _makePubliclyDecryptable(uint256HandleA);
        bytes memory data = abi.encode(123456);
        bytes memory proof = TestHelper.buildDecryptionProof(
            uint256HandleA,
            data,
            gatewayPrivateKey
        );
        uint256 result = noxMock.publicDecryptEuint256(uint256HandleA, proof);
        assertEq(result, 123456);
    }

    function test_RevertWhen_PublicDecrypt_Euint256_DataSizeTooSmall() public {
        _makePubliclyDecryptable(uint256HandleA);
        bytes memory data = abi.encodePacked(uint248(123456)); // < 32 bytes
        bytes memory proof = TestHelper.buildDecryptionProof(
            uint256HandleA,
            data,
            gatewayPrivateKey
        );
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEuint256(uint256HandleA, proof);
    }

    function test_publicDecrypt_Eint16() public {
        _makePubliclyDecryptable(int16HandleA);
        bytes memory data = abi.encodePacked(int16(-7));
        bytes memory proof = TestHelper.buildDecryptionProof(int16HandleA, data, gatewayPrivateKey);
        int16 result = noxMock.publicDecryptEint16(int16HandleA, proof);
        assertEq(result, -7);
    }

    function test_RevertWhen_PublicDecrypt_Eint16_DataSizeTooSmall() public {
        _makePubliclyDecryptable(int16HandleA);
        bytes memory data = abi.encodePacked(int8(-7)); // < 2 bytes
        bytes memory proof = TestHelper.buildDecryptionProof(int16HandleA, data, gatewayPrivateKey);
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEint16(int16HandleA, proof);
    }

    function test_RevertWhen_PublicDecrypt_Eint16_DataSizeTooLarge() public {
        _makePubliclyDecryptable(int16HandleA);
        bytes memory data = abi.encodePacked(int24(-7)); // > 2 bytes
        bytes memory proof = TestHelper.buildDecryptionProof(int16HandleA, data, gatewayPrivateKey);
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEint16(int16HandleA, proof);
    }

    function test_publicDecrypt_Eint256() public {
        _makePubliclyDecryptable(int256HandleA);
        bytes memory data = abi.encode(-999);
        bytes memory proof = TestHelper.buildDecryptionProof(
            int256HandleA,
            data,
            gatewayPrivateKey
        );
        int256 result = noxMock.publicDecryptEint256(int256HandleA, proof);
        assertEq(result, -999);
    }

    function test_RevertWhen_PublicDecrypt_Eint256_DataSizeTooSmall() public {
        _makePubliclyDecryptable(int256HandleA);
        bytes memory data = abi.encodePacked(int248(-999)); // < 32 bytes
        bytes memory proof = TestHelper.buildDecryptionProof(
            int256HandleA,
            data,
            gatewayPrivateKey
        );
        vm.expectRevert(abi.encodeWithSelector(Nox.MalformedDecryptedData.selector, data));
        noxMock.publicDecryptEint256(int256HandleA, proof);
    }

    // ============ Helpers ============

    function _makePubliclyDecryptable(bytes32 handle) internal {
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxComputeContract.allowPublicDecryption(handle);
    }

    function _noxFromExternal(bytes32 handle, bytes memory proof) internal returns (bytes32) {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            return ebool.unwrap(noxMock.fromExternalEbool(externalEbool.wrap(handle), proof));
        }
        if (t == TEEType.Uint16) {
            return euint16.unwrap(noxMock.fromExternalEuint16(externalEuint16.wrap(handle), proof));
        }
        if (t == TEEType.Uint256) {
            return
                euint256.unwrap(noxMock.fromExternalEuint256(externalEuint256.wrap(handle), proof));
        }
        if (t == TEEType.Int16) {
            return eint16.unwrap(noxMock.fromExternalEint16(externalEint16.wrap(handle), proof));
        }
        if (t == TEEType.Int256) {
            return eint256.unwrap(noxMock.fromExternalEint256(externalEint256.wrap(handle), proof));
        }
        revert("unsupported type");
    }

    function _noxAdd(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.add(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.add(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.add(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.add(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxSub(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.sub(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.sub(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.sub(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.sub(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxMul(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.mul(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.mul(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.mul(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.mul(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxDiv(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return euint16.unwrap(Nox.div(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return euint256.unwrap(Nox.div(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return eint16.unwrap(Nox.div(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return eint256.unwrap(Nox.div(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxSafeAdd(bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeAdd(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        }
        if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeAdd(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        }
        if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeAdd(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        }
        if (t == TEEType.Int256) {
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
        }
        if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeSub(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        }
        if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeSub(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        }
        if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeSub(eint256.wrap(a), eint256.wrap(b));
            return (ebool.unwrap(s), eint256.unwrap(r));
        }
        revert("unsupported type");
    }

    function _noxSafeMul(bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeMul(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        }
        if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeMul(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        }
        if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeMul(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        }
        if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeMul(eint256.wrap(a), eint256.wrap(b));
            return (ebool.unwrap(s), eint256.unwrap(r));
        }
        revert("unsupported type");
    }

    function _noxSafeDiv(bytes32 a, bytes32 b) internal returns (bytes32, bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            (ebool s, euint16 r) = Nox.safeDiv(euint16.wrap(a), euint16.wrap(b));
            return (ebool.unwrap(s), euint16.unwrap(r));
        }
        if (t == TEEType.Uint256) {
            (ebool s, euint256 r) = Nox.safeDiv(euint256.wrap(a), euint256.wrap(b));
            return (ebool.unwrap(s), euint256.unwrap(r));
        }
        if (t == TEEType.Int16) {
            (ebool s, eint16 r) = Nox.safeDiv(eint16.wrap(a), eint16.wrap(b));
            return (ebool.unwrap(s), eint16.unwrap(r));
        }
        if (t == TEEType.Int256) {
            (ebool s, eint256 r) = Nox.safeDiv(eint256.wrap(a), eint256.wrap(b));
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
        }
        if (t == TEEType.Uint256) {
            return
                euint256.unwrap(
                    Nox.select(ebool.wrap(condition), euint256.wrap(ifTrue), euint256.wrap(ifFalse))
                );
        }
        if (t == TEEType.Int16) {
            return
                eint16.unwrap(
                    Nox.select(ebool.wrap(condition), eint16.wrap(ifTrue), eint16.wrap(ifFalse))
                );
        }
        if (t == TEEType.Int256) {
            return
                eint256.unwrap(
                    Nox.select(ebool.wrap(condition), eint256.wrap(ifTrue), eint256.wrap(ifFalse))
                );
        }
        revert("unsupported type");
    }

    function _noxEq(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return ebool.unwrap(Nox.eq(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return ebool.unwrap(Nox.eq(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return ebool.unwrap(Nox.eq(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return ebool.unwrap(Nox.eq(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxNe(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return ebool.unwrap(Nox.ne(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return ebool.unwrap(Nox.ne(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return ebool.unwrap(Nox.ne(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return ebool.unwrap(Nox.ne(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxLt(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return ebool.unwrap(Nox.lt(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return ebool.unwrap(Nox.lt(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return ebool.unwrap(Nox.lt(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return ebool.unwrap(Nox.lt(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxLe(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return ebool.unwrap(Nox.le(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return ebool.unwrap(Nox.le(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return ebool.unwrap(Nox.le(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return ebool.unwrap(Nox.le(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxGt(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return ebool.unwrap(Nox.gt(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return ebool.unwrap(Nox.gt(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return ebool.unwrap(Nox.gt(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return ebool.unwrap(Nox.gt(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxGe(bytes32 a, bytes32 b) internal returns (bytes32) {
        TEEType t = a.typeOf();
        if (t == TEEType.Uint16) {
            return ebool.unwrap(Nox.ge(euint16.wrap(a), euint16.wrap(b)));
        }
        if (t == TEEType.Uint256) {
            return ebool.unwrap(Nox.ge(euint256.wrap(a), euint256.wrap(b)));
        }
        if (t == TEEType.Int16) {
            return ebool.unwrap(Nox.ge(eint16.wrap(a), eint16.wrap(b)));
        }
        if (t == TEEType.Int256) {
            return ebool.unwrap(Nox.ge(eint256.wrap(a), eint256.wrap(b)));
        }
        revert("unsupported type");
    }

    function _noxAllow(bytes32 handle, address acc) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.allow(ebool.wrap(handle), acc);
        } else if (t == TEEType.Uint16) {
            Nox.allow(euint16.wrap(handle), acc);
        } else if (t == TEEType.Uint256) {
            Nox.allow(euint256.wrap(handle), acc);
        } else if (t == TEEType.Int16) {
            Nox.allow(eint16.wrap(handle), acc);
        } else if (t == TEEType.Int256) {
            Nox.allow(eint256.wrap(handle), acc);
        } else {
            revert("unsupported type");
        }
    }

    function _noxAllowThis(bytes32 handle) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.allowThis(ebool.wrap(handle));
        } else if (t == TEEType.Uint16) {
            Nox.allowThis(euint16.wrap(handle));
        } else if (t == TEEType.Uint256) {
            Nox.allowThis(euint256.wrap(handle));
        } else if (t == TEEType.Int16) {
            Nox.allowThis(eint16.wrap(handle));
        } else if (t == TEEType.Int256) {
            Nox.allowThis(eint256.wrap(handle));
        } else {
            revert("unsupported type");
        }
    }

    function _noxAllowTransient(bytes32 handle, address acc) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.allowTransient(ebool.wrap(handle), acc);
        } else if (t == TEEType.Uint16) {
            Nox.allowTransient(euint16.wrap(handle), acc);
        } else if (t == TEEType.Uint256) {
            Nox.allowTransient(euint256.wrap(handle), acc);
        } else if (t == TEEType.Int16) {
            Nox.allowTransient(eint16.wrap(handle), acc);
        } else if (t == TEEType.Int256) {
            Nox.allowTransient(eint256.wrap(handle), acc);
        } else {
            revert("unsupported type");
        }
    }

    function _noxDisallowTransient(bytes32 handle, address acc) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.disallowTransient(ebool.wrap(handle), acc);
        } else if (t == TEEType.Uint16) {
            Nox.disallowTransient(euint16.wrap(handle), acc);
        } else if (t == TEEType.Uint256) {
            Nox.disallowTransient(euint256.wrap(handle), acc);
        } else if (t == TEEType.Int16) {
            Nox.disallowTransient(eint16.wrap(handle), acc);
        } else if (t == TEEType.Int256) {
            Nox.disallowTransient(eint256.wrap(handle), acc);
        } else {
            revert("unsupported type");
        }
    }

    function _noxIsAllowed(bytes32 handle, address acc) internal view {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.isAllowed(ebool.wrap(handle), acc);
        } else if (t == TEEType.Uint16) {
            Nox.isAllowed(euint16.wrap(handle), acc);
        } else if (t == TEEType.Uint256) {
            Nox.isAllowed(euint256.wrap(handle), acc);
        } else if (t == TEEType.Int16) {
            Nox.isAllowed(eint16.wrap(handle), acc);
        } else if (t == TEEType.Int256) {
            Nox.isAllowed(eint256.wrap(handle), acc);
        } else {
            revert("unsupported type");
        }
    }

    function _noxAddViewer(bytes32 handle, address viewer) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.addViewer(ebool.wrap(handle), viewer);
        } else if (t == TEEType.Uint16) {
            Nox.addViewer(euint16.wrap(handle), viewer);
        } else if (t == TEEType.Uint256) {
            Nox.addViewer(euint256.wrap(handle), viewer);
        } else if (t == TEEType.Int16) {
            Nox.addViewer(eint16.wrap(handle), viewer);
        } else if (t == TEEType.Int256) {
            Nox.addViewer(eint256.wrap(handle), viewer);
        } else {
            revert("unsupported type");
        }
    }

    function _noxIsViewer(bytes32 handle, address viewer) internal view {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.isViewer(ebool.wrap(handle), viewer);
        } else if (t == TEEType.Uint16) {
            Nox.isViewer(euint16.wrap(handle), viewer);
        } else if (t == TEEType.Uint256) {
            Nox.isViewer(euint256.wrap(handle), viewer);
        } else if (t == TEEType.Int16) {
            Nox.isViewer(eint16.wrap(handle), viewer);
        } else if (t == TEEType.Int256) {
            Nox.isViewer(eint256.wrap(handle), viewer);
        } else {
            revert("unsupported type");
        }
    }

    function _noxAllowPublicDecryption(bytes32 handle) internal {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.allowPublicDecryption(ebool.wrap(handle));
        } else if (t == TEEType.Uint16) {
            Nox.allowPublicDecryption(euint16.wrap(handle));
        } else if (t == TEEType.Uint256) {
            Nox.allowPublicDecryption(euint256.wrap(handle));
        } else if (t == TEEType.Int16) {
            Nox.allowPublicDecryption(eint16.wrap(handle));
        } else if (t == TEEType.Int256) {
            Nox.allowPublicDecryption(eint256.wrap(handle));
        } else {
            revert("unsupported type");
        }
    }

    function _noxIsPubliclyDecryptable(bytes32 handle) internal view {
        TEEType t = handle.typeOf();
        if (t == TEEType.Bool) {
            Nox.isPubliclyDecryptable(ebool.wrap(handle));
        } else if (t == TEEType.Uint16) {
            Nox.isPubliclyDecryptable(euint16.wrap(handle));
        } else if (t == TEEType.Uint256) {
            Nox.isPubliclyDecryptable(euint256.wrap(handle));
        } else if (t == TEEType.Int16) {
            Nox.isPubliclyDecryptable(eint16.wrap(handle));
        } else if (t == TEEType.Int256) {
            Nox.isPubliclyDecryptable(eint256.wrap(handle));
        } else {
            revert("unsupported type");
        }
    }

    /**
     * Asserts that a call is made to the noxCompute contract with the given
     * selector and arguments.
     */
    function _expectCall(bytes4 selector, bytes32 arg1, bytes32 arg2) internal {
        vm.expectCall(noxCompute, abi.encodeWithSelector(selector, arg1, arg2));
    }

    /**
     * Asserts that the given handle has the expected TEE type.
     */
    function _assertHandleType(bytes32 handle, TEEType expected) internal pure {
        assertEq(uint8(handle.typeOf()), uint8(expected), "type mismatch");
    }
}
