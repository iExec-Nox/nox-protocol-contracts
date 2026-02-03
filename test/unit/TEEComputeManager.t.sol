// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TEEComputeManager} from "../../contracts/TEEComputeManager.sol";
import {ACL} from "../../contracts/ACL.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {TEEType, TypeUtils, UnsupportedType} from "../../contracts/shared/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";
import {IErrors} from "../../contracts/interfaces/IErrors.sol";

contract TEEComputeManagerTest is Test {
    address owner = makeAddr("owner");
    address caller = makeAddr("caller");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    ACL aclContract;
    address acl;
    TEEComputeManager teeComputeManager;
    uint256 createdAt = block.timestamp;
    bytes32 handle = TestHelper.createHandle(TEEType.Uint256);

    // Arithmetic operation selectors
    bytes4[] internal arithmeticOps;
    // Comparison operation selectors
    bytes4[] internal comparisonOps;
    // Safe arithmetic operation selectors
    bytes4[] internal safeArithmeticOps;

    function setUp() public {
        (aclContract, teeComputeManager) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        vm.label(caller, "caller");

        // Initialize arithmetic operations
        arithmeticOps = new bytes4[](4);
        arithmeticOps[0] = ITEEComputeManager.add.selector;
        arithmeticOps[1] = ITEEComputeManager.sub.selector;
        arithmeticOps[2] = ITEEComputeManager.mul.selector;
        arithmeticOps[3] = ITEEComputeManager.div.selector;

        // Initialize comparison operations
        comparisonOps = new bytes4[](6);
        comparisonOps[0] = ITEEComputeManager.eq.selector;
        comparisonOps[1] = ITEEComputeManager.ne.selector;
        comparisonOps[2] = ITEEComputeManager.lt.selector;
        comparisonOps[3] = ITEEComputeManager.le.selector;
        comparisonOps[4] = ITEEComputeManager.gt.selector;
        comparisonOps[5] = ITEEComputeManager.ge.selector;

        // Initialize safe arithmetic operations
        safeArithmeticOps = new bytes4[](2);
        safeArithmeticOps[0] = ITEEComputeManager.safeAdd.selector;
        safeArithmeticOps[1] = ITEEComputeManager.safeSub.selector;
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertEq(teeComputeManager.owner(), owner);
        assertEq(address(teeComputeManager.ACL()), acl);
        (
            , // bytes1 fields
            string memory name,
            string memory version,
            , // uint256 chainId
            , // address verifyingContract
            , // uint256[] memory extensions, // bytes32 salt

        ) = teeComputeManager.eip712Domain();
        assertTrue(keccak256(bytes(name)) == keccak256(bytes("TEEComputeManager")));
        assertTrue(keccak256(bytes(version)) == keccak256(bytes("1")));
    }

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        teeComputeManager.initialize(owner);
    }

    // ============ setGateway ============

    function test_SetGateway() public {
        assertTrue(teeComputeManager.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.GatewayUpdated(newGateway);
        teeComputeManager.setGateway(newGateway);
        assertTrue(teeComputeManager.gateway() == newGateway);
    }

    function test_RevertWhen_SetGateway_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        address newGateway = makeAddr("newGateway");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedCaller);
        teeComputeManager.setGateway(newGateway);
    }

    function test_RevertWhen_SetGateway_ZeroAddress() public {
        vm.expectRevert(IErrors.InvalidZeroAddress.selector);
        vm.prank(owner);
        teeComputeManager.setGateway(address(0));
    }

    // ============ plaintextToEncrypted ============

    function test_PlaintextToEncrypted_Bool() public {
        uint256 value = 1;
        vm.expectCall(acl, abi.encodeWithSelector(ACL.allowTransient.selector));
        vm.prank(caller);
        bytes32 result = teeComputeManager.plaintextToEncrypted(value, TEEType.Bool);

        assertTrue(result != bytes32(0));
        assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Bool));
    }

    function test_PlaintextToEncrypted_Uint256() public {
        uint256 value = 42;
        vm.expectCall(acl, abi.encodeWithSelector(ACL.allowTransient.selector));
        vm.prank(caller);
        bytes32 result = teeComputeManager.plaintextToEncrypted(value, TEEType.Uint256);

        assertTrue(result != bytes32(0));
        assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Uint256));
        assertEq(uint8(result[31]), 0);
    }

    function test_PlaintextToEncrypted_Int256() public {
        int256 value = -999;
        vm.expectCall(acl, abi.encodeWithSelector(ACL.allowTransient.selector));
        vm.prank(caller);
        bytes32 result = teeComputeManager.plaintextToEncrypted(uint256(value), TEEType.Int256);

        assertTrue(result != bytes32(0));
        assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Int256));
    }

    function test_PlaintextToEncrypted_UniqueHandles() public {
        uint256 value = 42;
        vm.prank(caller);
        bytes32 result1 = teeComputeManager.plaintextToEncrypted(value, TEEType.Uint256);
        vm.warp(block.timestamp + 1);
        vm.prank(caller);
        bytes32 result2 = teeComputeManager.plaintextToEncrypted(value, TEEType.Uint256);

        assertTrue(result1 != result2);
    }

    function test_RevertWhen_PlaintextToEncrypted_UnsupportedType() public {
        uint256 value = 42;
        vm.prank(caller);
        vm.expectRevert(UnsupportedType.selector);
        teeComputeManager.plaintextToEncrypted(value, TEEType.Uint160);
    }

    // ============ validateProof ============

    function test_ValidateProof() public {
        address app = makeAddr("app");
        bytes memory proof = _buildProof(handle, owner, app, createdAt, gatewayPrivateKey);
        vm.expectCall(acl, abi.encodeCall(ACL(acl).allowTransient, (handle, app)), 1);
        vm.prank(app);
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(ACL(acl).isAllowed(handle, app));
    }

    function test_ValidateProof_RevertWhen_ChainIdMismatch() public {
        bytes32 badHandle = TestHelper.createHandle(type(uint32).max, TEEType.Uint256);
        bytes memory proof = _buildProof(
            badHandle,
            owner,
            address(this),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Handle chain id mismatch"
            )
        );
        teeComputeManager.validateProof(badHandle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_HandleTypeMismatch() public {
        bytes memory proof = _buildProof(
            handle,
            owner,
            address(this),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Handle type mismatch"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Bool); // Wrong type
    }

    function test_RevertWhen_ValidateProof_InvalidProofLength() public {
        bytes memory longProof = new bytes(138);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                longProof,
                "Invalid proof length"
            )
        );
        teeComputeManager.validateProof(handle, owner, longProof, TEEType.Uint256);
        bytes memory shortProof = new bytes(136);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                shortProof,
                "Invalid proof length"
            )
        );
        teeComputeManager.validateProof(handle, owner, shortProof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidAppInProof() public {
        address badApp = makeAddr("badApp");
        bytes memory proof = _buildProof(handle, owner, badApp, createdAt, gatewayPrivateKey);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.InvalidProof.selector, proof, "App mismatch")
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidOwnerInProof() public {
        address badOwner = makeAddr("badOwner");
        bytes memory proof = _buildProof(
            handle,
            badOwner,
            address(this),
            createdAt,
            gatewayPrivateKey
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Owner mismatch"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    function test_RevertWhen_ValidateProof_InvalidSigner() public {
        uint256 badSigner = 9999;
        bytes memory proof = _buildProof(handle, owner, address(this), createdAt, badSigner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITEEComputeManager.InvalidProof.selector,
                proof,
                "Invalid signature"
            )
        );
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }

    // ============ Arithmetic Operations (add, sub, mul, div) ============

    function test_ArithmeticOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (arithmeticOps[i] == ITEEComputeManager.add.selector) {
                emit ITEEComputeManager.Add(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (arithmeticOps[i] == ITEEComputeManager.sub.selector) {
                emit ITEEComputeManager.Sub(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (arithmeticOps[i] == ITEEComputeManager.mul.selector) {
                emit ITEEComputeManager.Mul(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (arithmeticOps[i] == ITEEComputeManager.div.selector) {
                emit ITEEComputeManager.Div(caller, leftHandOperand, rightHandOperand, bytes32(0));
            }
            vm.prank(caller);
            bytes32 result = _callArithmeticOperation(
                arithmeticOps[i],
                leftHandOperand,
                rightHandOperand
            );
            assertTrue(result != bytes32(0));
            assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Uint256));
        }
    }

    function test_RevertWhen_ArithmeticOperations_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITEEComputeManager.ACLNotAllowed.selector,
                    leftHandOperand,
                    caller
                )
            );
            _callArithmeticOperation(arithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_ArithmeticOperations_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITEEComputeManager.ACLNotAllowed.selector,
                    rightHandOperand,
                    caller
                )
            );
            _callArithmeticOperation(arithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_ArithmeticOperations_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
            _callArithmeticOperation(arithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_ArithmeticOperations_UnsupportedType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < arithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(UnsupportedType.selector);
            _callArithmeticOperation(arithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    // ============ Comparison Operations (eq, ne, lt, le, gt, ge) ============

    function test_ComparisonOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < comparisonOps.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (comparisonOps[i] == ITEEComputeManager.eq.selector) {
                emit ITEEComputeManager.Eq(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == ITEEComputeManager.ne.selector) {
                emit ITEEComputeManager.Ne(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == ITEEComputeManager.lt.selector) {
                emit ITEEComputeManager.Lt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == ITEEComputeManager.le.selector) {
                emit ITEEComputeManager.Le(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == ITEEComputeManager.gt.selector) {
                emit ITEEComputeManager.Gt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (comparisonOps[i] == ITEEComputeManager.ge.selector) {
                emit ITEEComputeManager.Ge(caller, leftHandOperand, rightHandOperand, bytes32(0));
            }
            vm.prank(caller);
            bytes32 result = _callComparisonOperation(
                comparisonOps[i],
                leftHandOperand,
                rightHandOperand
            );
            assertTrue(result != bytes32(0));
            assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Bool));
        }
    }

    function test_RevertWhen_ComparisonOperations_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < comparisonOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITEEComputeManager.ACLNotAllowed.selector,
                    leftHandOperand,
                    caller
                )
            );
            _callComparisonOperation(comparisonOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_ComparisonOperations_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

        for (uint256 i = 0; i < comparisonOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITEEComputeManager.ACLNotAllowed.selector,
                    rightHandOperand,
                    caller
                )
            );
            _callComparisonOperation(comparisonOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_ComparisonOperations_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < comparisonOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
            _callComparisonOperation(comparisonOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_ComparisonOperations_UnsupportedType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < comparisonOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(UnsupportedType.selector);
            _callComparisonOperation(comparisonOps[i], leftHandOperand, rightHandOperand);
        }
    }

    // ============ Safe Arithmetic Operations (safeAdd, safeSub) ============

    function test_SafeArithmeticOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (safeArithmeticOps[i] == ITEEComputeManager.safeAdd.selector) {
                emit ITEEComputeManager.SafeAdd(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else if (safeArithmeticOps[i] == ITEEComputeManager.safeSub.selector) {
                emit ITEEComputeManager.SafeSub(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            }
            vm.prank(caller);
            (bytes32 success, bytes32 result) = _callSafeArithmeticOperation(
                safeArithmeticOps[i],
                leftHandOperand,
                rightHandOperand
            );
            assertTrue(success != bytes32(0));
            assertTrue(result != bytes32(0));
            assertTrue(success != result);
            assertEq(uint8(TypeUtils.typeOf(success)), uint8(TEEType.Bool));
            assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Uint256));
        }
    }

    function test_RevertWhen_SafeArithmeticOperations_LhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITEEComputeManager.ACLNotAllowed.selector,
                    leftHandOperand,
                    caller
                )
            );
            _callSafeArithmeticOperation(safeArithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_SafeArithmeticOperations_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITEEComputeManager.ACLNotAllowed.selector,
                    rightHandOperand,
                    caller
                )
            );
            _callSafeArithmeticOperation(safeArithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_SafeArithmeticOperations_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
            _callSafeArithmeticOperation(safeArithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_SafeArithmeticOperations_UnsupportedType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < safeArithmeticOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(UnsupportedType.selector);
            _callSafeArithmeticOperation(safeArithmeticOps[i], leftHandOperand, rightHandOperand);
        }
    }

    // ============ select ============

    function test_Select() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(condition, caller);
        _allow(ifTrue, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit ITEEComputeManager.Select(caller, condition, ifTrue, ifFalse, bytes32(0));
        bytes32 result = teeComputeManager.select(condition, ifTrue, ifFalse);

        assertTrue(result != bytes32(0));
        assertEq(uint8(TypeUtils.typeOf(result)), uint8(TEEType.Uint256));
    }

    function test_RevertWhen_Select_ConditionNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(ifTrue, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, condition, caller)
        );
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfTrueNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(condition, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, ifTrue, caller)
        );
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfFalseNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(condition, caller);
        _allow(ifTrue, caller);

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.ACLNotAllowed.selector, ifFalse, caller)
        );
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IncompatibleTypes() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Int256);
        _allow(condition, caller);
        _allow(ifTrue, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_UnsupportedConditionType() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(condition, caller);
        _allow(ifTrue, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(UnsupportedType.selector);
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    // ============ isAllowed ============

    function test_IsAllowed() public {
        bytes32 h = TestHelper.createHandle(1, TEEType.Uint256);
        address account = makeAddr("account");

        assertFalse(teeComputeManager.isAllowed(h, account));

        _allow(h, account);

        assertTrue(teeComputeManager.isAllowed(h, account));
    }

    // ============ isViewer ============

    function test_IsViewer() public {
        bytes32 h = TestHelper.createHandle(1, TEEType.Uint256);
        address viewer = makeAddr("viewer");

        assertFalse(teeComputeManager.isViewer(h, viewer));

        _allow(h, caller);
        vm.prank(caller);
        aclContract.addViewer(h, viewer);

        assertTrue(teeComputeManager.isViewer(h, viewer));
    }

    // ============ isPubliclyDecryptable ============

    function test_IsPubliclyDecryptable() public {
        bytes32 h = TestHelper.createHandle(1, TEEType.Uint256);

        assertFalse(teeComputeManager.isPubliclyDecryptable(h));

        _allow(h, caller);
        vm.prank(caller);
        aclContract.allowPublicDecryption(h);

        assertTrue(teeComputeManager.isPubliclyDecryptable(h));
    }

    // ============ _authorizeUpgrade ============

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new TEEComputeManager(acl));
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        teeComputeManager.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradeToAndCall_UnauthorizedCaller() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedUpgrader);
        teeComputeManager.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Test Helpers ============

    function _allow(bytes32 h, address account) internal {
        vm.prank(address(teeComputeManager));
        aclContract.allowTransient(h, address(this));
        aclContract.allow(h, account);
    }

    function _callArithmeticOperation(
        bytes4 selector,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) internal returns (bytes32) {
        (bool success, bytes memory returnData) = address(teeComputeManager).call(
            abi.encodeWithSelector(selector, leftHandOperand, rightHandOperand)
        );
        require(success, "Arithmetic operation failed");
        return abi.decode(returnData, (bytes32));
    }

    function _callSafeArithmeticOperation(
        bytes4 selector,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) internal returns (bytes32, bytes32) {
        (bool success, bytes memory returnData) = address(teeComputeManager).call(
            abi.encodeWithSelector(selector, leftHandOperand, rightHandOperand)
        );
        require(success, "Safe arithmetic operation failed");
        return abi.decode(returnData, (bytes32, bytes32));
    }

    function _callComparisonOperation(
        bytes4 selector,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) internal returns (bytes32) {
        (bool success, bytes memory returnData) = address(teeComputeManager).call(
            abi.encodeWithSelector(selector, leftHandOperand, rightHandOperand)
        );
        require(success, "Comparison operation failed");
        return abi.decode(returnData, (bytes32));
    }

    function _buildProof(
        bytes32 handle_,
        address owner_,
        address app_,
        uint256 createdAt_,
        uint256 signerPrivateKey
    ) internal view returns (bytes memory) {
        // HandleProof(bytes32 handle,address owner,address app,uint256 createdAt)
        bytes32 structHash = keccak256(
            abi.encode(teeComputeManager.HANDLE_PROOF_TYPEHASH(), handle_, owner_, app_, createdAt_)
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(
            teeComputeManager.domainSeparator(),
            structHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(bytes20(owner_), bytes20(app_), bytes32(createdAt_), r, s, v);
    }
}
