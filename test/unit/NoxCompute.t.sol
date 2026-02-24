// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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
    UnsupportedType,
    NonArithmeticType
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

    // Binary operation selectors (arithmetic + comparison + safe arithmetic)
    bytes4[] internal binaryOps;

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway);
        vm.label(caller, "caller");

        binaryOps = new bytes4[](12);
        binaryOps[0] = INoxCompute.add.selector;
        binaryOps[1] = INoxCompute.sub.selector;
        binaryOps[2] = INoxCompute.mul.selector;
        binaryOps[3] = INoxCompute.div.selector;
        binaryOps[4] = INoxCompute.eq.selector;
        binaryOps[5] = INoxCompute.ne.selector;
        binaryOps[6] = INoxCompute.lt.selector;
        binaryOps[7] = INoxCompute.le.selector;
        binaryOps[8] = INoxCompute.gt.selector;
        binaryOps[9] = INoxCompute.ge.selector;
        binaryOps[10] = INoxCompute.safeAdd.selector;
        binaryOps[11] = INoxCompute.safeSub.selector;
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
        noxCompute.initialize(owner, vm.randomBytes(33));
    }

    function test_RevertWhen_Initialize_EmptyKmsPublicKey() public {
        NoxCompute impl = new NoxCompute();
        NoxCompute proxy = NoxCompute(TestHelper.deployProxy(address(impl)));
        vm.expectRevert(INoxCompute.InvalidEmptyBytes.selector);
        proxy.initialize(owner, "");
    }

    // ============ setKmsPublicKey ============

    function test_SetKmsPublicKey() public {
        // 33-byte compressed SEC1 secp256k1 public key
        bytes memory newKey = vm.randomBytes(33);
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.KmsPublicKeyUpdated(newKey);
        noxCompute.setKmsPublicKey(newKey);
        assertEq(noxCompute.kmsPublicKey(), newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        bytes memory newKey = vm.randomBytes(33);
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

    // ============ plaintextToEncrypted ============

    function test_PlaintextToEncrypted_Bool() public {
        bytes32 value = bytes32(uint256(1));
        vm.prank(caller);
        bytes32 result = noxCompute.plaintextToEncrypted(value, TEEType.Bool);

        _assertValidHandle(result, TEEType.Bool);
    }

    function test_PlaintextToEncrypted_Uint256() public {
        bytes32 value = bytes32(uint256(42));
        vm.prank(caller);
        bytes32 result = noxCompute.plaintextToEncrypted(value, TEEType.Uint256);

        _assertValidHandle(result, TEEType.Uint256);
    }

    function test_PlaintextToEncrypted_Int256() public {
        bytes32 value = bytes32(uint256(int256(-999)));
        vm.prank(caller);
        bytes32 result = noxCompute.plaintextToEncrypted(value, TEEType.Int256);

        _assertValidHandle(result, TEEType.Int256);
    }

    function test_PlaintextToEncrypted_UniqueHandles() public {
        bytes32 value = bytes32(uint256(42));
        vm.prank(caller);
        bytes32 result1 = noxCompute.plaintextToEncrypted(value, TEEType.Uint256);
        vm.warp(block.timestamp + 1);
        vm.prank(caller);
        bytes32 result2 = noxCompute.plaintextToEncrypted(value, TEEType.Uint256);

        assertTrue(result1 != result2);
    }

    function test_RevertWhen_PlaintextToEncrypted_UnsupportedType() public {
        bytes32 value = bytes32(uint256(42));
        // Use low-level call to pass invalid TEEType value (100) which is > Bytes32 (99)
        vm.prank(caller);
        (bool success, ) = address(noxCompute).call(
            abi.encodeWithSelector(
                INoxCompute.plaintextToEncrypted.selector,
                value,
                uint256(100) // Pass as uint256 to match function signature
            )
        );
        assertFalse(success);
    }

    // ============ validateProof ============

    function test_ValidateProof() public {
        address app = makeAddr("app");
        bytes memory proof = TestHelper.buildProof(
            address(noxCompute),
            handle,
            owner,
            app,
            createdAt,
            gatewayPrivateKey
        );
        vm.prank(app);
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(noxCompute.isAllowed(handle, app));
    }

    function test_ValidateProof_RevertWhen_ChainIdMismatch() public {
        uint256 wrongChainId = type(uint32).max;
        bytes32 badHandle = TestHelper.createHandle(wrongChainId, TEEType.Uint256);
        bytes memory proof = TestHelper.buildProof(
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
        noxCompute.validateProof(badHandle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_HandleTypeMismatch() public {
        bytes memory proof = TestHelper.buildProof(
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
        noxCompute.validateProof(handle, owner, proof, TEEType.Bool); // Wrong type
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
        noxCompute.validateProof(handle, owner, longProof, TEEType.Uint256);
        bytes memory shortProof = new bytes(136);
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.InvalidProof.selector,
                shortProof,
                "Invalid proof length"
            )
        );
        noxCompute.validateProof(handle, owner, shortProof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidAppInProof() public {
        address badApp = makeAddr("badApp");
        bytes memory proof = TestHelper.buildProof(
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
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidOwnerInProof() public {
        address badOwner = makeAddr("badOwner");
        bytes memory proof = TestHelper.buildProof(
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
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidSigner() public {
        uint256 badSigner = 9999;
        bytes memory proof = TestHelper.buildProof(
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
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_ValidateProof_NotExpiredWhenWithinDuration() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 30 minutes;
        bytes memory proof = TestHelper.buildProof(
            address(noxCompute),
            handle,
            owner,
            app,
            proofCreatedAt,
            gatewayPrivateKey
        );

        // Should succeed since proof is still within expiration window
        vm.prank(app);
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(noxCompute.isAllowed(handle, app));
    }

    function test_ValidateProof_NotExpiredAtExactBoundary() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 1 hours;
        bytes memory proof = TestHelper.buildProof(
            address(noxCompute),
            handle,
            owner,
            app,
            proofCreatedAt,
            gatewayPrivateKey
        );

        // Should succeed since block.timestamp == createdAt + expirationDuration (not >)
        vm.prank(app);
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(noxCompute.isAllowed(handle, app));
    }

    function test_RevertWhen_ValidateProof_Expired() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 1 hours - 1;
        bytes memory proof = TestHelper.buildProof(
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
        noxCompute.validateProof(handle, owner, proof, TEEType.Uint256);
    }
    // ============ Arithmetic Operations (add, sub, mul, div) ============

    function test_ArithmeticOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(leftHandOperand, caller);
        TestHelper.forceAllow(rightHandOperand, caller);

        bytes4[4] memory ops = [
            INoxCompute.add.selector,
            INoxCompute.sub.selector,
            INoxCompute.mul.selector,
            INoxCompute.div.selector
        ];
        for (uint256 i = 0; i < ops.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (ops[i] == INoxCompute.add.selector) {
                emit INoxCompute.Add(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.sub.selector) {
                emit INoxCompute.Sub(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.mul.selector) {
                emit INoxCompute.Mul(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.div.selector) {
                emit INoxCompute.Div(caller, leftHandOperand, rightHandOperand, bytes32(0));
            }
            vm.prank(caller);
            bytes32 result = _callBinaryOperation(ops[i], leftHandOperand, rightHandOperand);
            _assertValidHandle(result, TEEType.Uint256);
        }
    }

    // ============ Comparison Operations (eq, ne, lt, le, gt, ge) ============

    function test_ComparisonOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(leftHandOperand, caller);
        TestHelper.forceAllow(rightHandOperand, caller);

        bytes4[6] memory ops = [
            INoxCompute.eq.selector,
            INoxCompute.ne.selector,
            INoxCompute.lt.selector,
            INoxCompute.le.selector,
            INoxCompute.gt.selector,
            INoxCompute.ge.selector
        ];
        for (uint256 i = 0; i < ops.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (ops[i] == INoxCompute.eq.selector) {
                emit INoxCompute.Eq(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.ne.selector) {
                emit INoxCompute.Ne(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.lt.selector) {
                emit INoxCompute.Lt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.le.selector) {
                emit INoxCompute.Le(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.gt.selector) {
                emit INoxCompute.Gt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == INoxCompute.ge.selector) {
                emit INoxCompute.Ge(caller, leftHandOperand, rightHandOperand, bytes32(0));
            }
            vm.prank(caller);
            bytes32 result = _callBinaryOperation(ops[i], leftHandOperand, rightHandOperand);
            _assertValidHandle(result, TEEType.Bool);
        }
    }

    // ============ Safe Arithmetic Operations (safeAdd, safeSub) ============

    function test_SafeArithmeticOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(leftHandOperand, caller);
        TestHelper.forceAllow(rightHandOperand, caller);

        bytes4[2] memory ops = [INoxCompute.safeAdd.selector, INoxCompute.safeSub.selector];
        for (uint256 i = 0; i < ops.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (ops[i] == INoxCompute.safeAdd.selector) {
                emit INoxCompute.SafeAdd(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else if (ops[i] == INoxCompute.safeSub.selector) {
                emit INoxCompute.SafeSub(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            }
            vm.prank(caller);
            (bytes32 success, bytes32 result) = _callSafeArithmeticOperation(
                ops[i],
                leftHandOperand,
                rightHandOperand
            );
            assertNotEq(success, result);
            _assertValidHandle(success, TEEType.Bool);
            _assertValidHandle(result, TEEType.Uint256);
        }
    }

    // ============ Binary Operations Revert Tests ============

    function test_RevertWhen_BinaryOperations_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(rightHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(INoxCompute.NotAllowed.selector, leftHandOperand, caller)
            );
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_BinaryOperations_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(leftHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(INoxCompute.NotAllowed.selector, rightHandOperand, caller)
            );
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_BinaryOperations_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Int256);
        TestHelper.forceAllow(leftHandOperand, caller);
        TestHelper.forceAllow(rightHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_BinaryOperations_NonArithmeticType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(TEEType.Bool);
        TestHelper.forceAllow(leftHandOperand, caller);
        TestHelper.forceAllow(rightHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(NonArithmeticType.selector);
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    // ============ select ============

    function test_Select() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(condition, caller);
        TestHelper.forceAllow(ifTrue, caller);
        TestHelper.forceAllow(ifFalse, caller);

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
        TestHelper.forceAllow(ifTrue, caller);
        TestHelper.forceAllow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, condition, caller));
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfTrueNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(condition, caller);
        TestHelper.forceAllow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, ifTrue, caller));
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfFalseNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(condition, caller);
        TestHelper.forceAllow(ifTrue, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, ifFalse, caller));
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IncompatibleTypes() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Int256);
        TestHelper.forceAllow(condition, caller);
        TestHelper.forceAllow(ifTrue, caller);
        TestHelper.forceAllow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_UnsupportedConditionType() public {
        bytes32 condition = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifTrue = TestHelper.createHandle(TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(condition, caller);
        TestHelper.forceAllow(ifTrue, caller);
        TestHelper.forceAllow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(UnsupportedType.selector);
        noxCompute.select(condition, ifTrue, ifFalse);
    }

    // ============ Transfer Tests ============

    function test_Transfer() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(amount, caller);

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
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(amount, caller);

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
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(amount, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, balanceTo, caller));
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    function test_RevertWhen_Transfer_AmountNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(balanceTo, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, amount, caller));
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    function test_RevertWhen_Transfer_IncompatibleTypes() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Int256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(amount, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.transfer(balanceFrom, balanceTo, amount);
    }

    // ============ Mint Tests ============

    function test_Mint() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(amount, caller);
        TestHelper.forceAllow(totalSupply, caller);

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
        TestHelper.forceAllow(amount, caller);
        TestHelper.forceAllow(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, balanceTo, caller));
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    function test_RevertWhen_Mint_AmountNotAllowed() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, amount, caller));
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    function test_RevertWhen_Mint_TotalSupplyNotAllowed() public {
        bytes32 balanceTo = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(amount, caller);

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
        TestHelper.forceAllow(balanceTo, caller);
        TestHelper.forceAllow(amount, caller);
        TestHelper.forceAllow(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.mint(balanceTo, amount, totalSupply);
    }

    // ============ Burn Tests ============

    function test_Burn() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(amount, caller);
        TestHelper.forceAllow(totalSupply, caller);

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
        TestHelper.forceAllow(amount, caller);
        TestHelper.forceAllow(totalSupply, caller);

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
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.NotAllowed.selector, amount, caller));
        noxCompute.burn(balanceFrom, amount, totalSupply);
    }

    function test_RevertWhen_Burn_TotalSupplyNotAllowed() public {
        bytes32 balanceFrom = TestHelper.createHandle(TEEType.Uint256);
        bytes32 amount = TestHelper.createHandle(TEEType.Uint256);
        bytes32 totalSupply = TestHelper.createHandle(TEEType.Uint256);
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(amount, caller);

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
        TestHelper.forceAllow(balanceFrom, caller);
        TestHelper.forceAllow(amount, caller);
        TestHelper.forceAllow(totalSupply, caller);

        vm.prank(caller);
        vm.expectRevert(INoxCompute.IncompatibleTypes.selector);
        noxCompute.burn(balanceFrom, amount, totalSupply);
    }

    // ============ isAllowed ============

    function test_IsAllowed() public {
        bytes32 h = TestHelper.createHandle(TEEType.Uint256);
        address account = makeAddr("account");

        assertFalse(noxCompute.isAllowed(h, account));

        TestHelper.forceAllow(h, account);

        assertTrue(noxCompute.isAllowed(h, account));
    }

    // ============ isViewer ============

    function test_IsViewer() public {
        bytes32 h = TestHelper.createHandle(TEEType.Uint256);
        address viewer = makeAddr("viewer");

        assertFalse(noxCompute.isViewer(h, viewer));

        TestHelper.forceAllow(h, caller);
        vm.prank(caller);
        noxCompute.addViewer(h, viewer);

        assertTrue(noxCompute.isViewer(h, viewer));
    }

    // ============ isPubliclyDecryptable ============

    function test_IsPubliclyDecryptable() public {
        bytes32 h = TestHelper.createHandle(TEEType.Uint256);

        assertFalse(noxCompute.isPubliclyDecryptable(h));

        TestHelper.forceAllow(h, caller);
        vm.prank(caller);
        noxCompute.allowPublicDecryption(h);

        assertTrue(noxCompute.isPubliclyDecryptable(h));
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
     **/

    function _assertValidHandle(bytes32 h, TEEType expectedType) internal view {
        assertTrue(h != bytes32(0), "Handle should not be zero");
        assertEq(bytes4(h << (26 * 8)), bytes4(uint32(block.chainid)), "Invalid chainId");
        assertEq(uint8(TypeUtils.typeOf(h)), uint8(expectedType), "Invalid type");
        assertEq(uint8(h[31]), 0, "Invalid version");
        assertTrue(noxCompute.isAllowed(h, caller), "Caller should be allowed for the handle");
    }

    function _callBinaryOperation(
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
