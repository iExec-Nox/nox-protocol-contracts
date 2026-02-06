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
import {IACL} from "../../contracts/interfaces/IACL.sol";
import {ITEEComputeManager} from "../../contracts/interfaces/ITEEComputeManager.sol";
import {
    TEEType,
    TypeUtils,
    UnsupportedType,
    NonArithmeticType
} from "../../contracts/shared/TypeUtils.sol";
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

    // Binary operation selectors (arithmetic + comparison + safe arithmetic)
    bytes4[] internal binaryOps;

    function setUp() public {
        (aclContract, teeComputeManager) = TestHelper.deploy(owner, gateway);
        acl = address(aclContract);
        vm.label(caller, "caller");

        binaryOps = new bytes4[](12);
        binaryOps[0] = ITEEComputeManager.add.selector;
        binaryOps[1] = ITEEComputeManager.sub.selector;
        binaryOps[2] = ITEEComputeManager.mul.selector;
        binaryOps[3] = ITEEComputeManager.div.selector;
        binaryOps[4] = ITEEComputeManager.eq.selector;
        binaryOps[5] = ITEEComputeManager.ne.selector;
        binaryOps[6] = ITEEComputeManager.lt.selector;
        binaryOps[7] = ITEEComputeManager.le.selector;
        binaryOps[8] = ITEEComputeManager.gt.selector;
        binaryOps[9] = ITEEComputeManager.ge.selector;
        binaryOps[10] = ITEEComputeManager.safeAdd.selector;
        binaryOps[11] = ITEEComputeManager.safeSub.selector;
    }

    // ============ initialize ============

    function test_Initialize() public view {
        assertEq(teeComputeManager.owner(), owner);
        assertEq(address(teeComputeManager.ACL()), acl);
        assertEq(teeComputeManager.proofExpirationDuration(), 1 hours);
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

    // ============ setProofExpirationDuration ============

    function test_SetProofExpirationDuration() public {
        // Default is set during initialization
        assertEq(teeComputeManager.proofExpirationDuration(), 1 hours);

        uint256 newDuration = 2 hours;
        vm.prank(owner);
        vm.expectEmit();
        emit ITEEComputeManager.ProofExpirationDurationUpdated(newDuration);
        teeComputeManager.setProofExpirationDuration(newDuration);
        assertEq(teeComputeManager.proofExpirationDuration(), newDuration);
    }

    function test_RevertWhen_SetProofExpirationDuration_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                teeComputeManager
            )
        );
        vm.prank(unauthorizedCaller);
        teeComputeManager.setProofExpirationDuration(2 hours);
    }

    // ============ plaintextToEncrypted ============

    function test_PlaintextToEncrypted_Bool() public {
        uint256 value = 1;
        vm.expectCall(acl, abi.encodeWithSelector(ACL.allowTransient.selector));
        vm.prank(caller);
        bytes32 result = teeComputeManager.plaintextToEncrypted(value, TEEType.Bool);

        _assertValidHandle(result, TEEType.Bool);
    }

    function test_PlaintextToEncrypted_Uint256() public {
        uint256 value = 42;
        vm.expectCall(acl, abi.encodeWithSelector(ACL.allowTransient.selector));
        vm.prank(caller);
        bytes32 result = teeComputeManager.plaintextToEncrypted(value, TEEType.Uint256);

        _assertValidHandle(result, TEEType.Uint256);
    }

    function test_PlaintextToEncrypted_Int256() public {
        int256 value = -999;
        vm.expectCall(acl, abi.encodeWithSelector(ACL.allowTransient.selector));
        vm.prank(caller);
        bytes32 result = teeComputeManager.plaintextToEncrypted(uint256(value), TEEType.Int256);

        _assertValidHandle(result, TEEType.Int256);
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
        // Use low-level call to pass invalid TEEType value (100) which is > Bytes32 (99)
        vm.prank(caller);
        (bool success, ) = address(teeComputeManager).call(
            abi.encodeWithSelector(
                ITEEComputeManager.plaintextToEncrypted.selector,
                value,
                uint256(100) // Pass as uint256 to match function signature
            )
        );
        assertFalse(success);
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

    function test_ValidateProof_NotExpiredWhenWithinDuration() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 30 minutes;
        bytes memory proof = _buildProof(handle, owner, app, proofCreatedAt, gatewayPrivateKey);

        // Should succeed since proof is still within expiration window
        vm.prank(app);
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(ACL(acl).isAllowed(handle, app));
    }

    function test_ValidateProof_NotExpiredAtExactBoundary() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 1 hours;
        bytes memory proof = _buildProof(handle, owner, app, proofCreatedAt, gatewayPrivateKey);

        // Should succeed since block.timestamp == createdAt + expirationDuration (not >)
        vm.prank(app);
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
        assertTrue(ACL(acl).isAllowed(handle, app));
    }

    function test_RevertWhen_ValidateProof_Expired() public {
        // Warp to a realistic timestamp
        vm.warp(1700000000);

        address app = makeAddr("app");
        uint256 proofCreatedAt = block.timestamp - 1 hours - 1;
        bytes memory proof = _buildProof(handle, owner, app, proofCreatedAt, gatewayPrivateKey);

        vm.expectRevert(
            abi.encodeWithSelector(ITEEComputeManager.InvalidProof.selector, proof, "Proof expired")
        );
        vm.prank(app);
        teeComputeManager.validateProof(handle, owner, proof, TEEType.Uint256);
    }
    // ============ Arithmetic Operations (add, sub, mul, div) ============

    function test_ArithmeticOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        bytes4[4] memory ops = [
            ITEEComputeManager.add.selector,
            ITEEComputeManager.sub.selector,
            ITEEComputeManager.mul.selector,
            ITEEComputeManager.div.selector
        ];
        for (uint256 i = 0; i < ops.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (ops[i] == ITEEComputeManager.add.selector) {
                emit ITEEComputeManager.Add(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.sub.selector) {
                emit ITEEComputeManager.Sub(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.mul.selector) {
                emit ITEEComputeManager.Mul(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.div.selector) {
                emit ITEEComputeManager.Div(caller, leftHandOperand, rightHandOperand, bytes32(0));
            }
            vm.prank(caller);
            bytes32 result = _callBinaryOperation(ops[i], leftHandOperand, rightHandOperand);
            _assertValidHandle(result, TEEType.Uint256);
        }
    }

    // ============ Comparison Operations (eq, ne, lt, le, gt, ge) ============

    function test_ComparisonOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        bytes4[6] memory ops = [
            ITEEComputeManager.eq.selector,
            ITEEComputeManager.ne.selector,
            ITEEComputeManager.lt.selector,
            ITEEComputeManager.le.selector,
            ITEEComputeManager.gt.selector,
            ITEEComputeManager.ge.selector
        ];
        for (uint256 i = 0; i < ops.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (ops[i] == ITEEComputeManager.eq.selector) {
                emit ITEEComputeManager.Eq(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.ne.selector) {
                emit ITEEComputeManager.Ne(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.lt.selector) {
                emit ITEEComputeManager.Lt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.le.selector) {
                emit ITEEComputeManager.Le(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.gt.selector) {
                emit ITEEComputeManager.Gt(caller, leftHandOperand, rightHandOperand, bytes32(0));
            } else if (ops[i] == ITEEComputeManager.ge.selector) {
                emit ITEEComputeManager.Ge(caller, leftHandOperand, rightHandOperand, bytes32(0));
            }
            vm.prank(caller);
            bytes32 result = _callBinaryOperation(ops[i], leftHandOperand, rightHandOperand);
            _assertValidHandle(result, TEEType.Bool);
        }
    }

    // ============ Safe Arithmetic Operations (safeAdd, safeSub) ============

    function test_SafeArithmeticOperations() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        bytes4[2] memory ops = [
            ITEEComputeManager.safeAdd.selector,
            ITEEComputeManager.safeSub.selector
        ];
        for (uint256 i = 0; i < ops.length; i++) {
            vm.expectEmit(true, false, false, false);
            if (ops[i] == ITEEComputeManager.safeAdd.selector) {
                emit ITEEComputeManager.SafeAdd(
                    caller,
                    leftHandOperand,
                    rightHandOperand,
                    bytes32(0),
                    bytes32(0)
                );
            } else if (ops[i] == ITEEComputeManager.safeSub.selector) {
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
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(IACL.NotAllowed.selector, leftHandOperand, caller)
            );
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_BinaryOperations_RhsNotAllowed() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Uint256);
        _allow(leftHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(IACL.NotAllowed.selector, rightHandOperand, caller)
            );
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_BinaryOperations_IncompatibleTypes() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Uint256);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Int256);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(ITEEComputeManager.IncompatibleTypes.selector);
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
        }
    }

    function test_RevertWhen_BinaryOperations_NonArithmeticType() public {
        bytes32 leftHandOperand = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 rightHandOperand = TestHelper.createHandle(2, TEEType.Bool);
        _allow(leftHandOperand, caller);
        _allow(rightHandOperand, caller);

        for (uint256 i = 0; i < binaryOps.length; i++) {
            vm.prank(caller);
            vm.expectRevert(NonArithmeticType.selector);
            _callBinaryOperation(binaryOps[i], leftHandOperand, rightHandOperand);
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

        _assertValidHandle(result, TEEType.Uint256);
    }

    function test_RevertWhen_Select_ConditionNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(ifTrue, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IACL.NotAllowed.selector, condition, caller));
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfTrueNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(condition, caller);
        _allow(ifFalse, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IACL.NotAllowed.selector, ifTrue, caller));
        teeComputeManager.select(condition, ifTrue, ifFalse);
    }

    function test_RevertWhen_Select_IfFalseNotAllowed() public {
        bytes32 condition = TestHelper.createHandle(1, TEEType.Bool);
        bytes32 ifTrue = TestHelper.createHandle(2, TEEType.Uint256);
        bytes32 ifFalse = TestHelper.createHandle(3, TEEType.Uint256);
        _allow(condition, caller);
        _allow(ifTrue, caller);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IACL.NotAllowed.selector, ifFalse, caller));
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
    }

    function _allow(bytes32 h, address account) internal {
        vm.prank(address(teeComputeManager));
        aclContract.allowTransient(h, address(this));
        aclContract.allow(h, account);
    }

    function _callBinaryOperation(
        bytes4 selector,
        bytes32 leftHandOperand,
        bytes32 rightHandOperand
    ) internal returns (bytes32) {
        (bool success, bytes memory returnData) = address(teeComputeManager).call(
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
        (bool success, bytes memory returnData) = address(teeComputeManager).call(
            abi.encodeWithSelector(selector, leftHandOperand, rightHandOperand)
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        return abi.decode(returnData, (bytes32, bytes32));
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
