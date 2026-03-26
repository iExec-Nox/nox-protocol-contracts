// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {
    TEEType,
    TypeUtils,
    NonArithmeticType,
    UnsupportedArithmeticType
} from "../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxComputeTest is Test {
    address owner = makeAddr("owner");
    address caller = makeAddr("caller");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    NoxCompute noxCompute;
    uint256 createdAt = block.timestamp;
    bytes32 handle = TestHelper.createHandle(TEEType.Uint256);

    bytes4[] arithmeticOps = [
        INoxCompute.add.selector,
        INoxCompute.sub.selector,
        INoxCompute.mul.selector,
        INoxCompute.div.selector
    ];
    bytes4[] safeArithmeticOps = [
        INoxCompute.safeAdd.selector,
        INoxCompute.safeSub.selector,
        INoxCompute.safeMul.selector,
        INoxCompute.safeDiv.selector
    ];
    bytes4[] comparisonOps = [
        INoxCompute.eq.selector,
        INoxCompute.ne.selector,
        INoxCompute.lt.selector,
        INoxCompute.le.selector,
        INoxCompute.gt.selector,
        INoxCompute.ge.selector
    ];
    // All operation selectors (arithmetic + comparison + safe arithmetic)
    bytes4[] internal allOps;

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway);
        vm.label(caller, "caller");
        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            allOps.push(arithmeticOps[i]);
        }
        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            allOps.push(safeArithmeticOps[i]);
        }
        for (uint256 i = 0; i < comparisonOps.length; i++) {
            allOps.push(comparisonOps[i]);
        }
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertEq(noxCompute.owner(), owner);
        assertEq(noxCompute.proofExpirationDuration(), 1 hours);
        (
            , // bytes1 fields
            string memory name,
            string memory version,
            , // uint256 chainId
            , // address verifyingContract
            , // uint256[] memory extensions, // bytes32 salt

        ) = noxCompute.eip712Domain();
        assertTrue(keccak256(bytes(name)) == keccak256(bytes("NoxCompute")));
        assertTrue(keccak256(bytes(version)) == keccak256(bytes("1")));
    }

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        noxCompute.initialize(owner, abi.encodePacked(bytes1(0x02), keccak256("reinit-kms-key")));
    }

    function test_RevertWhen_Initialize_EmptyKmsPublicKey() public {
        NoxCompute impl = new NoxCompute();
        vm.expectRevert(INoxCompute.InvalidEmptyBytes.selector);
        NoxCompute(TestHelper.deployProxy(address(impl), owner, new bytes(0)));
    }

    // ============ setKmsPublicKey ============

    function test_SetKmsPublicKey() public {
        // 33-byte compressed SEC1 secp256k1 public key
        bytes memory newKey = abi.encodePacked(bytes1(0x02), keccak256("new-kms-key"));
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.KmsPublicKeyUpdated(newKey);
        noxCompute.setKmsPublicKey(newKey);
        assertEq(noxCompute.kmsPublicKey(), newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        bytes memory newKey = abi.encodePacked(bytes1(0x02), keccak256("unauthorized-kms-key"));
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setKmsPublicKey(newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_EmptyKey() public {
        vm.expectRevert(INoxCompute.InvalidEmptyBytes.selector);
        vm.prank(owner);
        noxCompute.setKmsPublicKey("");
    }

    // ============ setGateway ============

    function test_SetGateway() public {
        assertTrue(noxCompute.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.GatewayUpdated(newGateway);
        noxCompute.setGateway(newGateway);
        assertTrue(noxCompute.gateway() == newGateway);
    }

    function test_RevertWhen_SetGateway_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        address newGateway = makeAddr("newGateway");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setGateway(newGateway);
    }

    function test_RevertWhen_SetGateway_ZeroAddress() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.setGateway(address(0));
    }

    // ============ setProofExpirationDuration ============

    function test_SetProofExpirationDuration() public {
        // Default is set during initialization
        assertEq(noxCompute.proofExpirationDuration(), 1 hours);

        uint256 newDuration = 2 hours;
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.ProofExpirationDurationUpdated(newDuration);
        noxCompute.setProofExpirationDuration(newDuration);
        assertEq(noxCompute.proofExpirationDuration(), newDuration);
    }

    function test_RevertWhen_SetProofExpirationDuration_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setProofExpirationDuration(2 hours);
    }

    // ============ wrapAsPublicHandle ============

    function test_WrapAsPublicHandle_Bool() public {
        bytes32 value = bytes32(uint256(1));
        vm.prank(caller);
        bytes32 result = noxCompute.wrapAsPublicHandle(value, TEEType.Bool);

        _assertValidPublicHandle(result, TEEType.Bool);
    }

    function test_WrapAsPublicHandle_Uint256() public {
        bytes32 value = bytes32(uint256(42));
        vm.prank(caller);
        bytes32 result = noxCompute.wrapAsPublicHandle(value, TEEType.Uint256);

        _assertValidPublicHandle(result, TEEType.Uint256);
    }

    function test_WrapAsPublicHandle_Int256() public {
        bytes32 value = bytes32(uint256(int256(-999)));
        vm.prank(caller);
        bytes32 result = noxCompute.wrapAsPublicHandle(value, TEEType.Int256);

        _assertValidPublicHandle(result, TEEType.Int256);
    }

    function test_WrapAsPublicHandle_Deterministic() public {
        bytes32 value = bytes32(uint256(42));
        vm.prank(caller);
        bytes32 result1 = noxCompute.wrapAsPublicHandle(value, TEEType.Uint256);
        vm.warp(block.timestamp + 1);
        vm.prank(caller);
        bytes32 result2 = noxCompute.wrapAsPublicHandle(value, TEEType.Uint256);

        // Same value + same type = same handle (deterministic, no msg.sender/block.timestamp)
        assertEq(result1, result2);
    }

    function test_WrapAsPublicHandle_DifferentValues() public {
        vm.prank(caller);
        bytes32 result1 = noxCompute.wrapAsPublicHandle(bytes32(uint256(1)), TEEType.Uint256);
        vm.prank(caller);
        bytes32 result2 = noxCompute.wrapAsPublicHandle(bytes32(uint256(2)), TEEType.Uint256);

        assertTrue(result1 != result2);
    }

    function test_RevertWhen_WrapAsPublicHandle_UnsupportedType() public {
        bytes32 value = bytes32(uint256(42));
        // Use low-level call to pass invalid TEEType value: size of TEEType + 1
        vm.prank(caller);
        (bool success, ) = address(noxCompute).call(
            abi.encodeWithSelector(
                INoxCompute.wrapAsPublicHandle.selector,
                value,
                uint8(type(TEEType).max) + 1
            )
        );
        assertFalse(success);
    }

    // ============ Handle uniqueness seed ============

    function test_UniqueHandles_AllPublicHandleOperands() public {
        // When all operands are public handles, the counter ensures unique handles
        vm.prank(caller);
        bytes32 publicA = noxCompute.wrapAsPublicHandle(bytes32(uint256(0)), TEEType.Uint256);
        // add(publicA, publicA) called twice should produce different handles
        vm.prank(caller);
        bytes32 result1 = noxCompute.add(publicA, publicA);
        vm.prank(caller);
        bytes32 result2 = noxCompute.add(publicA, publicA);
        assertTrue(result1 != result2, "Should be unique handles due to uniqueSeedCounter");
    }

    // ============ validateInputProof ============

    function test_ValidateProof() public {
        this._test_ValidateProof();
    }
    function _test_ValidateProof() external {
        address app = makeAddr("app");
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            app,
            createdAt,
            gatewayPrivateKey
        );
        vm.prank(app);
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(noxCompute.isAllowed(handle, app));
    }

    function test_ValidateProof_RevertWhen_ChainIdMismatch() public {
        uint256 wrongChainId = type(uint32).max;
        bytes32 badHandle = TestHelper.createHandle(wrongChainId, TEEType.Uint256);
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            badHandle,
            owner,
            address(this),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.InvalidProof.selector,
                proof,
                "Handle chain id mismatch"
            )
        );
        noxCompute.validateInputProof(badHandle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_HandleTypeMismatch() public {
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            address(this),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.InvalidProof.selector, proof, "Handle type mismatch")
        );
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Bool); // Wrong type
    }

    function test_RevertWhen_ValidateProof_InvalidProofLength() public {
        bytes memory longProof = new bytes(138);
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.InvalidProof.selector,
                longProof,
                "Invalid proof length"
            )
        );
        noxCompute.validateInputProof(handle, owner, longProof, TEEType.Uint256);
        bytes memory shortProof = new bytes(136);
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.InvalidProof.selector,
                shortProof,
                "Invalid proof length"
            )
        );
        noxCompute.validateInputProof(handle, owner, shortProof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidAppInProof() public {
        address badApp = makeAddr("badApp");
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            badApp,
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.InvalidProof.selector, proof, "App mismatch")
        );
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidOwnerInProof() public {
        address badOwner = makeAddr("badOwner");
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            badOwner,
            address(this),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.InvalidProof.selector, proof, "Owner mismatch")
        );
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidSigner() public {
        uint256 badSigner = 9999;
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            address(this),
            createdAt,
            badSigner
        );
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.InvalidProof.selector, proof, "Invalid signature")
        );
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_ValidateProof_NotExpiredWhenWithinDuration() public {
        this._test_ValidateProof_NotExpiredWhenWithinDuration();
    }
    function _test_ValidateProof_NotExpiredWhenWithinDuration() external {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 30 minutes;
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            app,
            proofCreatedAt,
            gatewayPrivateKey
        );

        // Should succeed since proof is still within expiration window
        vm.prank(app);
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(noxCompute.isAllowed(handle, app));
    }

    function test_ValidateProof_NotExpiredAtExactBoundary() public {
        this._test_ValidateProof_NotExpiredAtExactBoundary();
    }
    function _test_ValidateProof_NotExpiredAtExactBoundary() external {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 1 hours;
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            app,
            proofCreatedAt,
            gatewayPrivateKey
        );

        // Should succeed since block.timestamp == createdAt + expirationDuration (not >)
        vm.prank(app);
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(noxCompute.isAllowed(handle, app));
    }

    function test_RevertWhen_ValidateProof_Expired() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 1 hours - 1;
        bytes memory proof = TestHelper.buildInputProof(
            address(noxCompute),
            handle,
            owner,
            app,
            proofCreatedAt,
            gatewayPrivateKey
        );

        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.InvalidProof.selector, proof, "Proof expired")
        );
        vm.prank(app);
        noxCompute.validateInputProof(handle, owner, proof, TEEType.Uint256);
    }

    // ============ validateDecryptionProof ============

    function test_ValidateDecryptionProof_With32Bytes() public {
        bytes memory decryptedValue = abi.encode(42);
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);
        bytes memory proof = TestHelper.buildDecryptionProof(
            handle,
            decryptedValue,
            gatewayPrivateKey
        );
        bytes memory result = noxCompute.validateDecryptionProof(handle, proof);
        assertEq(result.length, 32);
        assertEq(result, decryptedValue);
        assertEq(uint8(bytes1(result[31])), 42);
    }

    function test_ValidateDecryptionProof_WithEncodingLargerThan32Bytes() public {
        bytes memory decryptedValue = abi.encodePacked(uint8(11), uint256(22));
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);
        bytes memory proof = TestHelper.buildDecryptionProof(
            handle,
            decryptedValue,
            gatewayPrivateKey
        );
        bytes memory result = noxCompute.validateDecryptionProof(handle, proof);
        assertEq(result.length, 33);
        assertEq(result, decryptedValue);
        assertEq(uint8(bytes1(result[0])), 11);
        assertEq(uint8(bytes1(result[32])), 22);
    }

    function test_ValidateDecryptionProof_WithEncodingSmallerThan32Bytes() public {
        bytes memory decryptedValue = abi.encodePacked(uint8(42));
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);
        bytes memory proof = TestHelper.buildDecryptionProof(
            handle,
            decryptedValue,
            gatewayPrivateKey
        );
        bytes memory result = noxCompute.validateDecryptionProof(handle, proof);
        assertEq(result.length, 1);
        assertEq(result, decryptedValue);
        assertEq(uint8(bytes1(result)), 42);
    }

    function test_ValidateDecryptionProof_WithEmptyBytesValue() public {
        bytes memory decryptedValue = new bytes(0);
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);
        bytes memory proof = TestHelper.buildDecryptionProof(
            handle,
            decryptedValue,
            gatewayPrivateKey
        );
        bytes memory result = noxCompute.validateDecryptionProof(handle, proof);
        assertEq(result.length, 0);
        assertEq(result, decryptedValue);
    }

    function test_RevertWhen_ValidateDecryptionProof_ProofTooShort() public {
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);
        bytes memory tooShortProof = new bytes(65 - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.InvalidProof.selector,
                tooShortProof,
                "Proof too short"
            )
        );
        noxCompute.validateDecryptionProof(handle, tooShortProof);
    }

    function test_RevertWhen_ValidateDecryptionProof_InvalidSigner() public {
        uint256 badSigner = 9999;
        TestHelper.forceAllowPersistent(handle, owner);
        vm.prank(owner);
        noxCompute.allowPublicDecryption(handle);
        bytes memory proof = TestHelper.buildDecryptionProof(handle, abi.encode(42), badSigner);
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.InvalidProof.selector, proof, "Invalid signature")
        );
        noxCompute.validateDecryptionProof(handle, proof);
    }

    // ============ Arithmetic Operations (add, sub, mul, div) ============

    function test_ArithmeticOperations() public {
        this._test_ArithmeticOperations();
    }
    function _test_ArithmeticOperations() external {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);
        TestHelper.forceAllowPersistent(rightHandOperand, caller);

        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (arithmeticOps[i] == INoxCompute.add.selector) {
                emit INoxCompute.Add(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (arithmeticOps[i] == INoxCompute.sub.selector) {
                emit INoxCompute.Sub(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (arithmeticOps[i] == INoxCompute.mul.selector) {
                emit INoxCompute.Mul(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (arithmeticOps[i] == INoxCompute.div.selector) {
                emit INoxCompute.Div(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else {
                revert("Not implemented");
            }
            vm.prank(caller);
            bytes32 result = _callOperation(arithmeticOps[i], leftHandOperand, rightHandOperand);
            _assertValidHandle(result, TEEType.Uint256);
        }
    }

    // ============ Comparison Operations (eq, ne, lt, le, gt, ge) ============

    function test_ComparisonOperations() public {
        this._test_ComparisonOperations();
    }
    function _test_ComparisonOperations() external {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);
        TestHelper.forceAllowPersistent(rightHandOperand, caller);

        for (uint256 i = 0; i < comparisonOps.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (comparisonOps[i] == INoxCompute.eq.selector) {
                emit INoxCompute.Eq(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == INoxCompute.ne.selector) {
                emit INoxCompute.Ne(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == INoxCompute.lt.selector) {
                emit INoxCompute.Lt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == INoxCompute.le.selector) {
                emit INoxCompute.Le(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == INoxCompute.gt.selector) {
                emit INoxCompute.Gt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == INoxCompute.ge.selector) {
                emit INoxCompute.Ge(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else {
                revert("Not implemented");
            }
            vm.prank(caller);
            bytes32 result = _callOperation(comparisonOps[i], leftHandOperand, rightHandOperand);
            _assertValidHandle(result, TEEType.Bool);
        }
    }

    // ============ Safe Arithmetic Operations (safeAdd, safeSub) ============

    function test_SafeArithmeticOperations() public {
        this._test_SafeArithmeticOperations();
    }
    function _test_SafeArithmeticOperations() external {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);
        TestHelper.forceAllowPersistent(rightHandOperand, caller);

        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (safeArithmeticOps[i] == INoxCompute.safeAdd.selector) {
                emit INoxCompute.SafeAdd(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else if (safeArithmeticOps[i] == INoxCompute.safeSub.selector) {
                emit INoxCompute.SafeSub(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else if (safeArithmeticOps[i] == INoxCompute.safeMul.selector) {
                emit INoxCompute.SafeMul(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else if (safeArithmeticOps[i] == INoxCompute.safeDiv.selector) {
                emit INoxCompute.SafeDiv(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else {
                revert("Not implemented");
            }
            vm.prank(caller);
            (bytes32 success, bytes32 result) = _callSafeArithmeticOperation(
                safeArithmeticOps[i],
                leftHandOperand,
                rightHandOperand
            );
            assertNotEq(success, result);
            _assertValidHandle(success, TEEType.Bool);
            _assertValidHandle(result, TEEType.Uint256);
        }
    }

    // ============ Operations Revert Tests ============

    function test_RevertWhen_AllOperations_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(rightHandOperand, caller);

        for (uint256 i = 0; i < allOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(INoxCompute.NotAllowed.selector, leftHandOperand, caller)
            );
            _callOperation(allOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_AllOperations_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);

        for (uint256 i = 0; i < allOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(INoxCompute.NotAllowed.selector, rightHandOperand, caller)
            );
            _callOperation(allOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_AllOperations_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Int256);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);
        TestHelper.forceAllowPersistent(rightHandOperand, caller);

        for (uint256 i = 0; i < allOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
            _callOperation(allOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_AllOperations_NonArithmeticType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Bool);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);
        TestHelper.forceAllowPersistent(rightHandOperand, caller);

        for (uint256 i = 0; i < allOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(NonArithmeticType.selector);
            _callOperation(allOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_AllOperations_UnsupportedArithmeticType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint8);
        bytes32 unsupportedTypeOperand = TestHelper.createHandle(TEEType.Uint8);
        TestHelper.forceAllowPersistent(leftHandOperand, caller);
        TestHelper.forceAllowPersistent(unsupportedTypeOperand, caller);

        for (uint256 i = 0; i < allOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(UnsupportedArithmeticType.selector);
            _callOperation(allOps[i], leftHandOperand, unsupportedTypeOperand);
        }
    }

    // ============ select ============

    function test_Select() public {
        this._test_Select();
    }
    function _test_Select() external {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(condition, caller);
        TestHelper.forceAllowPersistent(ifTrue, caller);
        TestHelper.forceAllowPersistent(ifFalse, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit INoxCompute.Select(caller, condition, ifTrue, ifFalse, bytes32(0));
        bytes32 result = noxCompute.select(condition, ifTrue, ifFalse);

        _assertValidHandle(result, TEEType.Uint256);
    }

    function test_RevertWhen_Select_ConditionNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(ifTrue, caller);
        TestHelper.forceAllowPersistent(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, condition, caller));
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfTrueNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(condition, caller);
        TestHelper.forceAllowPersistent(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, ifTrue, caller));
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfFalseNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(condition, caller);
        TestHelper.forceAllowPersistent(ifTrue, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, ifFalse, caller));
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IncompatibleTypes() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Int256);
        TestHelper.forceAllowPersistent(condition, caller);
        TestHelper.forceAllowPersistent(ifTrue, caller);
        TestHelper.forceAllowPersistent(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_UnsupportedConditionType() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(condition, caller);
        TestHelper.forceAllowPersistent(ifTrue, caller);
        TestHelper.forceAllowPersistent(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.UnsupportedType.selector);
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    // ============ Transfer Tests ============

    function test_Transfer() public {
        this._test_Transfer();
    }
    function _test_Transfer() external {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(amount, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit INoxCompute.Transfer(
            caller,
            balanceFrom,
            balanceTo,
            amount,
            bytes32(0),
            bytes32(0),
            bytes32(0)
        );
        (bytes32 success, bytes32 newBalanceFrom, bytes32 newBalanceTo) = noxCompute.transfer(
            balanceFrom,
            balanceTo,
            amount
        );

        _assertValidHandle(success, TEEType.Bool);
        _assertValidHandle(newBalanceFrom, TEEType.Uint256);
        _assertValidHandle(newBalanceTo, TEEType.Uint256);
    }

    function test_RevertWhen_Transfer_BalanceFromNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(amount, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.NotAllowed.selector, balanceFrom, caller)
        );
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    function test_RevertWhen_Transfer_BalanceToNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(amount, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, balanceTo, caller));
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    function test_RevertWhen_Transfer_AmountNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(balanceTo, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, amount, caller));
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    function test_RevertWhen_Transfer_IncompatibleTypes() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Int256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(amount, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    // ============ Mint Tests ============

    function test_Mint() public {
        this._test_Mint();
    }
    function _test_Mint() external {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(amount, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit INoxCompute.Mint(
            caller,
            balanceTo,
            amount,
            totalSupply,
            bytes32(0),
            bytes32(0),
            bytes32(0)
        );
        (bytes32 success, bytes32 newBalanceTo, bytes32 newTotalSupply) = noxCompute.mint(
            balanceTo,
            amount,
            totalSupply
        );

        _assertValidHandle(success, TEEType.Bool);
        _assertValidHandle(newBalanceTo, TEEType.Uint256);
        _assertValidHandle(newTotalSupply, TEEType.Uint256);
    }

    function test_RevertWhen_Mint_BalanceToNotAllowed() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(amount, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, balanceTo, caller));
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    function test_RevertWhen_Mint_AmountNotAllowed() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, amount, caller));
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    function test_RevertWhen_Mint_TotalSupplyNotAllowed() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(amount, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.NotAllowed.selector, totalSupply, caller)
        );
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    function test_RevertWhen_Mint_IncompatibleTypes() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Int256);
        TestHelper.forceAllowPersistent(balanceTo, caller);
        TestHelper.forceAllowPersistent(amount, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    // ============ Burn Tests ============

    function test_Burn() public {
        this._test_Burn();
    }
    function _test_Burn() external {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(amount, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit INoxCompute.Burn(
            caller,
            balanceFrom,
            amount,
            totalSupply,
            bytes32(0),
            bytes32(0),
            bytes32(0)
        );
        (bytes32 success, bytes32 newBalanceFrom, bytes32 newTotalSupply) = noxCompute.burn(
            balanceFrom,
            amount,
            totalSupply
        );

        _assertValidHandle(success, TEEType.Bool);
        _assertValidHandle(newBalanceFrom, TEEType.Uint256);
        _assertValidHandle(newTotalSupply, TEEType.Uint256);
    }

    function test_RevertWhen_Burn_BalanceFromNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(amount, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.NotAllowed.selector, balanceFrom, caller)
        );
        noxCompute.burn(balanceFrom, amount, totalSupply);
    }

    function test_RevertWhen_Burn_AmountNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, amount, caller));
        noxCompute.burn(balanceFrom, amount, totalSupply);
    }

    function test_RevertWhen_Burn_TotalSupplyNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(amount, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.NotAllowed.selector, totalSupply, caller)
        );
        noxCompute.burn(balanceFrom, amount, totalSupply);
    }

    function test_RevertWhen_Burn_IncompatibleTypes() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Int256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllowPersistent(balanceFrom, caller);
        TestHelper.forceAllowPersistent(amount, caller);
        TestHelper.forceAllowPersistent(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.burn(balanceFrom, amount, totalSupply);
    }

    // ============ _authorizeUpgrade ============

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new NoxCompute());
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        noxCompute.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradeToAndCall_UnauthorizedCaller() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                noxCompute
            )
        );
        vm.prank(unauthorizedUpgrader);
        noxCompute.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Test Helpers ============
    /**
     * TODO: Add tests for private helper functions:
     *   - _executeArithmeticOperation
     *   - _generateHandle
     *
     */

    function _assertValidHandle(bytes32 h, TEEType expectedType) internal view {
        _assertValidHandle(h, expectedType, false);
    }

    function _assertValidPublicHandle(bytes32 h, TEEType expectedType) internal view {
        _assertValidHandle(h, expectedType, true);
    }

    function _assertValidHandle(bytes32 h, TEEType expectedType, bool isPublic) internal view {
        assertTrue(h != bytes32(0), "Handle should not be zero");
        assertEq(uint8(h[0]), 0, "Invalid version");
        assertEq(bytes4(h << (1 * 8)), bytes4(uint32(block.chainid)), "Invalid chainId");
        assertEq(uint8(TypeUtils.typeOf(h)), uint8(expectedType), "Invalid type");
        if (isPublic) {
            assertTrue(TypeUtils.isPublicHandle(h), "Should be a public handle");
        } else {
            assertEq(uint8(h[6]) & 0x01, 1, "Should have isUniqueHandle=1");
            assertTrue(noxCompute.isAllowed(h, caller), "Caller should be allowed for the handle");
        }
    }

    function _callOperation(
        bytes4 selector,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) internal returns (bytes32) {
        (bool success, bytes memory returnData) = address(noxCompute).call(
            abi.encodeWithSelector(selector, leftHandOperand, rightHandOperand)
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        return bytes32(returnData);
    }

    function _callSafeArithmeticOperation(
        bytes4 selector,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) internal returns (bytes32, bytes32) {
        (bool success, bytes memory returnData) = address(noxCompute).call(
            abi.encodeWithSelector(selector, leftHandOperand, rightHandOperand)
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        return abi.decode(returnData, (bytes32, bytes32));
    }
}
